//
//  CategoryIcon.swift
//  Xpnse
//

import Foundation

enum CategoryIcon {
    static let defaultEmoji = "🏷️"
    static let unknownFallbackEmoji = "❓"

    static func isEmojiIcon(_ value: String) -> Bool {
        normalizedEmojiOrNil(value) != nil
    }

    static func isSFSymbolIcon(_ value: String) -> Bool {
        !isEmojiIcon(value)
    }

    /// Returns a single emoji after trimming, or `nil` if empty/invalid.
    static func normalizedEmojiOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count == 1, let character = trimmed.first else { return nil }
        guard character.isEmojiIconCharacter else { return nil }
        return String(character)
    }

    /// Empty input → `fallback`. Valid emoji → that emoji. Invalid non-empty → `nil`.
    static func resolvedIcon(
        from input: String,
        fallback: String = defaultEmoji
    ) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return fallback
        }
        return normalizedEmojiOrNil(trimmed)
    }
}

private extension Character {
    /// True when this grapheme cluster is a usable emoji icon.
    var isEmojiIconCharacter: Bool {
        let scalars = Array(unicodeScalars)
        guard !scalars.isEmpty else { return false }

        // Reject ASCII / Latin-1 text even if Unicode marks some as emoji-capable.
        if scalars.allSatisfy({ $0.value <= 0xFF }) {
            return false
        }

        if scalars.contains(where: { $0.properties.isEmojiPresentation }) {
            return true
        }

        if scalars.contains(where: { $0.properties.isEmoji }) {
            let hasVariationSelector = scalars.contains { $0.value == 0xFE0F }
            let hasKeycap = scalars.contains { $0.value == 0x20E3 }
            if hasVariationSelector || hasKeycap {
                return true
            }
            // Single-scalar emoji symbols without default emoji presentation (e.g. ⭐).
            if scalars.count == 1 {
                return true
            }
            return scalars.contains {
                $0.properties.isEmojiModifierBase || $0.properties.isEmojiModifier
            }
        }

        return false
    }
}
