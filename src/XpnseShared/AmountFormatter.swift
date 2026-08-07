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

    /// Editable amount string without currency (TextField). No grouping separators.
    /// Formats via `NumberFormatter` on the `Double` so binary float noise (e.g. 172.799999998) rounds to 2 dp.
    static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value))
            ?? formatForEditing(Decimal(value))
    }

    static func format(_ value: Decimal) -> String {
        formatForEditing(value)
    }

    /// Plain editable amount: no grouping, POSIX decimal point, up to 2 fraction digits.
    static func formatForEditing(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    /// Parses an amount typed in an entry field (plain or locale-grouped).
    static func parseDecimal(_ string: String) -> Decimal? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let posix = NumberFormatter()
        posix.numberStyle = .decimal
        posix.locale = Locale(identifier: "en_US_POSIX")
        posix.usesGroupingSeparator = false
        if let number = posix.number(from: trimmed) {
            return number.decimalValue
        }

        let localized = NumberFormatter()
        localized.numberStyle = .decimal
        localized.locale = .current
        if let number = localized.number(from: trimmed) {
            return number.decimalValue
        }

        return nil
    }

    /// Decimal amount without currency (display). Prefer `format(_:currencyCode:)` for money.
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
