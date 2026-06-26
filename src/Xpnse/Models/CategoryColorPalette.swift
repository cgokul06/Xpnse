//
//  CategoryColorPalette.swift
//  Xpnse
//

import Foundation

/// Category colors stored and exchanged as `#RRGGBB` hex strings.
enum CategoryColorPalette {
    static let defaultHex = "#9CA3AF"

    static let colors: [String] = [
        "#EF4444", "#F97316", "#F59E0B", "#EAB308", "#84CC16", "#22C55E",
        "#10B981", "#14B8A6", "#06B6D4", "#0EA5E9", "#3B82F6", "#6366F1",
        "#8B5CF6", "#A855F7", "#D946EF", "#EC4899", "#F43F5E", "#FB7185",
        "#FDA4AF", "#FDBA74", "#FDE047", "#BEF264", "#86EFAC", "#6EE7B7",
        "#5EEAD4", "#67E8F9", "#7DD3FC", "#93C5FD", "#A5B4FC", "#C4B5FD",
        "#D8B4FE", "#F0ABFC", "#F9A8D4", "#FCA5A5", "#78716C", "#64748B"
    ]

    static func normalizedHex(_ hex: String) -> String {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !value.hasPrefix("#") {
            value = "#\(value)"
        }
        if value.count == 4 {
            let chars = Array(value.dropFirst())
            value = "#" + chars.map { String($0) + String($0) }.joined()
        }
        return value
    }

    static func isValid(_ hex: String) -> Bool {
        let normalized = normalizedHex(hex)
        guard normalized.count == 7, normalized.hasPrefix("#") else { return false }
        return normalized.dropFirst().allSatisfy(\.isHexDigit)
    }

    static func isSuggested(_ hex: String) -> Bool {
        colors.contains(normalizedHex(hex))
    }

    static func defaultHex(for transactionType: TransactionType) -> String {
        switch transactionType {
        case .expense:
            return colors[10]
        case .income:
            return colors[5]
        }
    }
}
