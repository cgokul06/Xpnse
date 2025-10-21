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
    @Published var extractedTransaction: Transaction?
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

    private func extractTransactionFromImage(_ image: UIImage) async throws -> Transaction {
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

    private func parseTransactionWithLanguageModel(_ extractedText: String) async throws -> Transaction {
        let prompt = """
        Analyze this receipt text and extract transaction information. 
        \(extractedText)
        """

        let session = LanguageModelSession()

        switch SystemLanguageModel.default.availability {
        case .available:
            // Show chat UI
            print("available")
        case .unavailable(let reason):
            let text = switch reason {
            case .appleIntelligenceNotEnabled:
                "Apple Intelligence is not enabled. Please enable it in Settings."
            case .deviceNotEligible:
                "This device is not eligible for Apple Intelligence. Please use a compatible device."
            case .modelNotReady:
                "The language model is not ready yet. Please try again later."
            @unknown default:
                "The language model is unavailable for an unknown reason."
            }
            print(text)
        }
        let c = try await session.respond(to: prompt, generating: Transaction.self)

        return c.content
    }

    // MARK: - Error Handling
    enum BillScannerError: Error, LocalizedError {
        case invalidImage
        case noTextFound
        case extractionFailed

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "Invalid image provided"
            case .noTextFound:
                return "No text found in the image"
            case .extractionFailed:
                return "Failed to extract data from image"
            }
        }
    }
}
