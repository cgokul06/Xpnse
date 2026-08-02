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

    /// Compact currency for dense UI (charts, summary cards).
    /// Composes locale currency symbol with the resolved compact number style.
    static func formatCompact(_ value: Double, currencyCode: String) -> String {
        formatCompact(Decimal(value), currencyCode: currencyCode)
    }

    static func formatCompact(_ value: Decimal, currencyCode: String) -> String {
        "\(currencySymbol(for: currencyCode))\(compactNumber(value))"
    }

    /// Compact number only (no currency). Resolves lakh/crore vs million style from preference/locale.
    static func compactNumber(_ value: Double) -> String {
        compactNumber(Decimal(value))
    }

    static func compactNumber(_ value: Decimal) -> String {
        CompactNumberFormatterFactory.makeResolved().format(value)
    }

    /// Compatibility wrapper for older call sites; delegates to the resolved compact formatter.
    static func abbreviatedFloor(_ value: Double, decimals: Int = 2) -> String {
        _ = decimals
        return compactNumber(value)
    }

    static func currencySymbol(for currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? currencyCode
    }

    private static func fallbackCurrency(_ value: Double, currencyCode: String) -> String {
        "\(currencyCode) \(formatDecimal(value))"
    }
}
