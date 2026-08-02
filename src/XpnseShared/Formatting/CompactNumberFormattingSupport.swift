//
//  CompactNumberFormattingSupport.swift
//  XpnseShared
//

import Foundation

enum CompactNumberFormattingSupport {
    static let thousand = Decimal(1_000)
    static let lakh = Decimal(100_000)
    static let crore = Decimal(10_000_000)
    static let million = Decimal(1_000_000)
    static let billion = Decimal(1_000_000_000)
    static let trillion = Decimal(1_000_000_000_000)

    /// Rounds half-up to `scale` fractional digits, then formats without grouping or trailing zeros.
    static func formatScaled(_ value: Decimal, divisor: Decimal, suffix: String) -> String {
        let isNegative = value < 0
        let absolute = abs(value)
        let scaled = absolute / divisor
        let rounded = roundHalfUp(scaled, scale: 2)
        let mantissa = formatMantissa(rounded)
        let body = "\(mantissa)\(suffix)"
        return isNegative ? "-\(body)" : body
    }

    static func formatPlain(_ value: Decimal) -> String {
        let isNegative = value < 0
        let absolute = abs(value)
        let rounded = roundHalfUp(absolute, scale: 2)
        let mantissa = formatMantissa(rounded)
        return isNegative ? "-\(mantissa)" : mantissa
    }

    static func roundHalfUp(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
    }

    private static func formatMantissa(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
