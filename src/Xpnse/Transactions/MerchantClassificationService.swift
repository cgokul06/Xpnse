//
//  MerchantClassificationService.swift
//  Xpnse
//

import Foundation
import FoundationModels

@Generable
struct MerchantClassification {
    @Guide(description: "True only when the description clearly names a known brand or company (e.g. Amazon, YouTube, Netflix). False for typos, generic words, food items, categories, or anything uncertain.")
    var isCertain: Bool

    @Guide(description: "Short brand/company name only when isCertain is true (e.g. Amazon, YouTube). Empty string otherwise. Never invent or spell-correct a merchant.")
    var merchantName: String
}

@MainActor
final class MerchantClassificationService {
    private var inferenceTask: Task<String?, Never>?

    /// Infers a concise merchant/brand name from a free-text description.
    /// Only returns a value when confidence is effectively certain — a known brand
    /// that clearly appears in the description. Does not use past transaction history.
    func infer(from description: String) async -> String? {
        inferenceTask?.cancel()

        let task = Task<String?, Never> { @MainActor in
            let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3 else { return nil }
            guard !Task.isCancelled else { return nil }
            guard FoundationModelsAvailability.isAvailable else { return nil }

            let prompt = """
            Extract a merchant/brand ONLY when you are certain it is a known company or brand named in the description.
            High-confidence examples (return these):
            - "Amazon Prime subscription" → Amazon
            - "YouTube Premium" → YouTube
            - "Google Play subscription" → Google
            - "Netflix monthly" → Netflix
            - "Uber trip to airport" → Uber
            - "Spotify family plan" → Spotify

            Return EMPTY when uncertain. Do NOT return a merchant for:
            - Typos or misspellings (e.g. "snakc", "amzon")
            - Generic product/category words (snacks, food, groceries, coffee, rent, salary)
            - Descriptions that do not clearly name a brand
            - Guessing or spell-correcting the description into a merchant

            The merchant must be a short brand/company name that is already present in the description text (not invented).
            Set isCertain to true only for the high-confidence brand cases above; otherwise isCertain false and merchantName empty.
            Description: \(trimmed)
            """

            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt, generating: MerchantClassification.self)
                guard !Task.isCancelled else { return nil }

                let content = response.content
                guard content.isCertain else { return nil }

                let name = content.merchantName
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard Self.isAcceptableMerchant(name, in: trimmed) else { return nil }
                return name
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

    /// Local gate: merchant must clearly appear in the description as a known brand extract.
    static func isAcceptableMerchant(_ merchant: String, in description: String) -> Bool {
        let merchantNormalized = normalizeForMatch(merchant)
        let descriptionNormalized = normalizeForMatch(description)

        guard merchantNormalized.count >= 2, merchantNormalized.count <= 32 else { return false }
        guard merchant.split(whereSeparator: \.isWhitespace).count <= 3 else { return false }

        // Reject typo-"corrections" of the whole description (e.g. snakc → snacks).
        if descriptionNormalized != merchantNormalized {
            let distance = levenshtein(descriptionNormalized, merchantNormalized)
            if distance > 0, distance <= 2, abs(descriptionNormalized.count - merchantNormalized.count) <= 2 {
                return false
            }
        }

        // Brand must already appear in the description (case/punctuation-insensitive).
        guard descriptionNormalized.contains(merchantNormalized) else { return false }

        // Prefer a proper brand extract: either the whole description is the brand,
        // or the merchant is shorter than the full description.
        if descriptionNormalized == merchantNormalized {
            return !isGenericWord(merchantNormalized)
        }

        return !isGenericWord(merchantNormalized)
    }

    private static func normalizeForMatch(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == " " {
                return Character(scalar)
            }
            return " "
        }
        return String(scalars)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static let genericWords: Set<String> = [
        "snack", "snacks", "food", "grocery", "groceries", "coffee", "tea",
        "lunch", "dinner", "breakfast", "rent", "salary", "income", "expense",
        "bill", "payment", "subscription", "monthly", "weekly", "daily",
        "transfer", "misc", "other", "cash", "tip", "tips"
    ]

    private static func isGenericWord(_ normalized: String) -> Bool {
        genericWords.contains(normalized)
    }

    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count
        if m == 0 { return n }
        if n == 0 { return m }

        var previous = Array(0...n)
        var current = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            current[0] = i
            for j in 1...n {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
            }
            previous = current
        }
        return previous[n]
    }
}
