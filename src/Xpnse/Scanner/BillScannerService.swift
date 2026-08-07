//
//  BillScannerService.swift
//  Xpnse
//
//  Created by Gokul C on 27/07/25.
//

import Foundation
import FoundationModels
import Vision
import VisionKit
import UIKit
import Combine

@MainActor
class BillScannerService: ObservableObject {
    @Published var isScanning = false
    @Published var extractedTransaction: ScannedTransaction?
    @Published var errorMessage: String?

    // MARK: - Scan Methods

    func scanBill(from image: UIImage) async {
        isScanning = true
        errorMessage = nil
        AppAnalytics.logEvent(AppAnalytics.Event.receiptScanStart)

        do {
            let extractedTransaction = try await extractTransactionFromImage(image)
            self.extractedTransaction = extractedTransaction
            AppAnalytics.logEvent(
                AppAnalytics.Event.receiptScanResult,
                parameters: [AppAnalytics.Param.result: "success"]
            )
            UserSatisfactionEngine.shared.track(.receiptScanned)
        } catch {
            errorMessage = L10n.tr("scanner.extract_failed", error.localizedDescription)
            AppAnalytics.logEvent(
                AppAnalytics.Event.receiptScanResult,
                parameters: [AppAnalytics.Param.result: "fail"]
            )
        }

        isScanning = false
    }

    /// Analyzes shared plain text for a transaction (Share Extension → Add Transaction).
    func analyzeSharedText(_ text: String) async {
        isScanning = true
        errorMessage = nil
        extractedTransaction = nil
        AppAnalytics.logEvent(AppAnalytics.Event.shareTextAnalyzeStart)

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = L10n.tr("share.empty_text")
            AppAnalytics.logEvent(
                AppAnalytics.Event.shareTextAnalyzeResult,
                parameters: [AppAnalytics.Param.result: "empty"]
            )
            isScanning = false
            return
        }

        do {
            let analysis = try await parseSharedTextWithLanguageModel(trimmed)
            guard analysis.isTransactionRelated else {
                errorMessage = L10n.tr("share.not_transaction")
                AppAnalytics.logEvent(
                    AppAnalytics.Event.shareTextAnalyzeResult,
                    parameters: [AppAnalytics.Param.result: "not_related"]
                )
                isScanning = false
                return
            }

            var scanned = analysis.asScannedTransaction()
            let defaultCategory = BuiltinCategories.defaultCategoryId(for: scanned.type)

            // Enforce missing-field policy (do not trust invented model filler).
            if !analysis.titleFoundInText {
                scanned.title = ""
            }
            if analysis.categoryFoundInText {
                scanned.categoryId = CategoryStore.shared.mapScannedCategoryId(
                    scanned.categoryId,
                    transactionType: scanned.type
                )
            } else {
                scanned.categoryId = defaultCategory
            }
            if !analysis.dateFoundInText {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = .current
                formatter.dateFormat = "yyyy-MM-dd"
                scanned.date = formatter.string(from: Date())
                scanned.dateFormat = "yyyy-MM-dd"
            }

            extractedTransaction = scanned
            AppAnalytics.logEvent(
                AppAnalytics.Event.shareTextAnalyzeResult,
                parameters: [AppAnalytics.Param.result: "success"]
            )
        } catch {
            errorMessage = error.localizedDescription
            AppAnalytics.logEvent(
                AppAnalytics.Event.shareTextAnalyzeResult,
                parameters: [AppAnalytics.Param.result: "fail"]
            )
        }

        isScanning = false
    }

    // MARK: - Data Extraction

    private func extractTransactionFromImage(_ image: UIImage) async throws -> ScannedTransaction {
        guard let cgImage = image.cgImage else {
            throw BillScannerError.invalidImage
        }

        var request = RecognizeTextRequest()
        request.recognitionLanguages = OCRLanguagePreferences.recognitionLanguages().map {
            Locale.Language(identifier: $0)
        }
        let res = try await request.perform(on: cgImage)
        var allText: [String] = []
        for c in res {
            guard let topCandidate = c.topCandidates(1).first else { continue }
            allText.append(topCandidate.string)
        }

        guard !allText.isEmpty else {
            throw BillScannerError.noTextFound
        }

        return try await parseTransactionWithLanguageModel(allText.joined(separator: "\n"))
    }

    // MARK: - LanguageModelSession Parsing

    private func parseTransactionWithLanguageModel(_ extractedText: String) async throws -> ScannedTransaction {
        await CategoryStore.shared.load()
        let expenseGuide = CategoryStore.shared.categoryGuideDescription(for: .expense)
        let savingsGuide = CategoryStore.shared.categoryGuideDescription(for: .savings)
        let incomeGuide = CategoryStore.shared.categoryGuideDescription(for: .income)
        let prompt = """
        Analyze this receipt text and extract transaction information. The date might be in different formats. Find the exact date format used here and map it to 'dateFormat' property.
        For categoryId: use expense categories (\(expenseGuide)) for expenses, savings categories (\(savingsGuide)) for savings, or income categories (\(incomeGuide)) for income. Receipts are usually expenses unless clearly income or savings.
        \(extractedText).
        """

        guard FoundationModelsAvailability.isAvailable else {
            throw BillScannerError.modelUnavailable(
                FoundationModelsAvailability.unavailabilityMessage
                    ?? L10n.tr("scanner.model_unavailable")
            )
        }

        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt, generating: ScannedTransaction.self)
        var scanned = response.content
        scanned.categoryId = CategoryStore.shared.mapScannedCategoryId(
            scanned.categoryId,
            transactionType: scanned.type
        )
        return scanned
    }

    private func parseSharedTextWithLanguageModel(
        _ sharedText: String
    ) async throws -> SharedTextTransactionAnalysis {
        await CategoryStore.shared.load()
        let expenseGuide = CategoryStore.shared.categoryGuideDescription(for: .expense)
        let savingsGuide = CategoryStore.shared.categoryGuideDescription(for: .savings)
        let incomeGuide = CategoryStore.shared.categoryGuideDescription(for: .income)
        let prompt = """
        Decide whether the following shared text describes a financial transaction \
        (purchase, payment, transfer, bill, refund, income, or savings). \
        Set isTransactionRelated to true only when it clearly does; otherwise false.

        When isTransactionRelated is true:
        - Extract amount when present.
        - titleFoundInText: true only if a merchant, payee, or description is explicitly stated; \
          otherwise false and set title to an empty string. Never invent a title.
        - categoryFoundInText: true only if a specific category is clearly stated or strongly implied; \
          otherwise false and set categoryId to the type default \
          (expense→\(BuiltinCategories.defaultCategoryId(for: .expense)), \
          savings→\(BuiltinCategories.defaultCategoryId(for: .savings)), \
          income→\(BuiltinCategories.defaultCategoryId(for: .income))). Never guess a category.
        - dateFoundInText: true only if an explicit calendar date appears; \
          otherwise false and set date to today's date with dateFormat yyyy-MM-dd. Never invent a date.
        - When categoryFoundInText is true, categoryId must be from: \
          expense (\(expenseGuide)); savings (\(savingsGuide)); income (\(incomeGuide)).
        Prefer expense when type is unclear but still transaction-related.

        When isTransactionRelated is false, use false for the *FoundInText flags and empty/zero placeholders.

        Shared text:
        \(sharedText)
        """

        guard FoundationModelsAvailability.isAvailable else {
            throw BillScannerError.modelUnavailable(
                FoundationModelsAvailability.unavailabilityMessage
                    ?? L10n.tr("scanner.model_unavailable")
            )
        }

        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt, generating: SharedTextTransactionAnalysis.self)
        return response.content
    }

    // MARK: - Error Handling
    enum BillScannerError: Error, LocalizedError {
        case invalidImage
        case noTextFound
        case extractionFailed
        case modelUnavailable(String)

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return L10n.tr("scanner.invalid_image")
            case .noTextFound:
                return L10n.tr("scanner.no_text")
            case .extractionFailed:
                return L10n.tr("scanner.extraction_failed")
            case .modelUnavailable(let message):
                return message
            }
        }
    }
}
