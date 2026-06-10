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

        do {
            let extractedTransaction = try await extractTransactionFromImage(image)
            self.extractedTransaction = extractedTransaction
        } catch {
            errorMessage = "Failed to extract data: \(error.localizedDescription)"
        }

        isScanning = false
    }

    // MARK: - Data Extraction

    private func extractTransactionFromImage(_ image: UIImage) async throws -> ScannedTransaction {
        guard let cgImage = image.cgImage else {
            throw BillScannerError.invalidImage
        }

        let res = try await RecognizeTextRequest().perform(on: cgImage)
        var allText: [String] = []
        for c in res {
            guard let topCandidate = c.topCandidates(1).first else { continue }
            allText.append(topCandidate.string)
        }

        return try await parseTransactionWithLanguageModel(allText.joined(separator: "\n"))
    }

    // MARK: - LanguageModelSession Parsing

    private func parseTransactionWithLanguageModel(_ extractedText: String) async throws -> ScannedTransaction {
        await CategoryStore.shared.load()
        let expenseGuide = CategoryStore.shared.categoryGuideDescription(for: .expense)
        let incomeGuide = CategoryStore.shared.categoryGuideDescription(for: .income)
        let prompt = """
        Analyze this receipt text and extract transaction information. The date might be in different formats. Find the exact date format used here and map it to 'dateFormat' property.
        For categoryId: use expense categories (\(expenseGuide)) for expenses, or income categories (\(incomeGuide)) for income.
        \(extractedText).
        """

        guard FoundationModelsAvailability.isAvailable else {
            throw BillScannerError.modelUnavailable(
                FoundationModelsAvailability.unavailabilityMessage
                    ?? "The language model is unavailable."
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
                return "Invalid image provided"
            case .noTextFound:
                return "No text found in the image"
            case .extractionFailed:
                return "Failed to extract data from image"
            case .modelUnavailable(let message):
                return message
            }
        }
    }
}
