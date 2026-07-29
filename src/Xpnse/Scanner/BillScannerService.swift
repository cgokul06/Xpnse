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
        } catch {
            errorMessage = L10n.tr("scanner.extract_failed", error.localizedDescription)
            AppAnalytics.logEvent(
                AppAnalytics.Event.receiptScanResult,
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
