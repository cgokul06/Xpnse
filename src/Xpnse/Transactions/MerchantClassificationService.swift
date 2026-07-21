//
//  MerchantClassificationService.swift
//  Xpnse
//

import Foundation
import FoundationModels

@Generable
struct MerchantClassification {
    @Guide(description: "Short merchant or brand name only (e.g. YouTube, Amazon, Google). Empty string if unclear.")
    var merchantName: String
}

@MainActor
final class MerchantClassificationService {
    private var inferenceTask: Task<String?, Never>?

    /// Infers a concise merchant/brand name from a free-text description.
    /// Does not use past transaction history — on-device language model only.
    func infer(from description: String) async -> String? {
        inferenceTask?.cancel()

        let task = Task<String?, Never> { @MainActor in
            let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3 else { return nil }
            guard !Task.isCancelled else { return nil }
            guard FoundationModelsAvailability.isAvailable else { return nil }

            let prompt = """
            Extract the merchant or brand name from this transaction description.
            Return only the short brand/merchant name people recognize (examples: "YouTube Premium" → YouTube, "Google Play subscription" → Google, "Amazon Prime subscription" → Amazon, "Netflix monthly" → Netflix, "Uber trip to airport" → Uber).
            Do not return the full description, plan names, or categories.
            If no clear merchant or brand is present, return an empty string.
            Description: \(trimmed)
            """

            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt, generating: MerchantClassification.self)
                guard !Task.isCancelled else { return nil }
                let name = response.content.merchantName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? nil : name
            } catch {
                return nil
            }
        }

        inferenceTask = task
        return await task.value
    }

    func cancel() {
        inferenceTask?.cancel()
        inferenceTask = nil
    }
}
