//
//  AmountFormatter.swift
//  XpnseShared
//

import Foundation

enum AmountFormatter {
    /// Locale-aware currency string. Never manually prepend currency symbols.
    static func format(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value))
            ?? fallbackCurrency(value, currencyCode: currencyCode)
    }

    static func format(_ value: Decimal, currencyCode: String) -> String {
        format((value as NSDecimalNumber).doubleValue, currencyCode: currencyCode)
    }

    /// Decimal amount without currency (e.g. entry fields). Prefer `format(_:currencyCode:)` for display.
    static func format(_ value: Double) -> String {
        formatDecimal(value)
    }

    static func format(_ value: Decimal) -> String {
        formatDecimal((value as NSDecimalNumber).doubleValue)
    }

    /// Decimal amount without currency (e.g. entry fields).
    static func formatDecimal(_ value: Double, fractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.\(fractionDigits)f", value)
    }

    static func formatPercent(_ ratio: Double, fractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = .current
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: ratio))
            ?? "\(Int((ratio * 100).rounded()))%"
    }

    /// Locale-aware compact currency for dense UI (charts, summary cards).
    static func formatCompact(_ value: Double, currencyCode: String) -> String {
        value.formatted(
            .currency(code: currencyCode)
                .locale(.current)
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }

    /// Locale-aware compact notation for charts and dense UI (no currency).
    static func abbreviatedFloor(_ value: Double, decimals: Int = 1) -> String {
        value.formatted(
            .number
                .locale(.current)
                .notation(.compactName)
                .precision(.fractionLength(0...max(0, decimals)))
        )
    }

    private static func fallbackCurrency(_ value: Double, currencyCode: String) -> String {
        "\(currencyCode) \(formatDecimal(value))"
    }
}
