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
    /// Uses floor-based abbreviations so values never round up (e.g. 198000 → ₹1.98L, not ₹2L).
    static func formatCompact(_ value: Double, currencyCode: String) -> String {
        "\(currencySymbol(for: currencyCode))\(abbreviatedFloor(value))"
    }

    /// Floor-based abbreviated units: K (thousand), L (lakh), M (million), C (crore).
    /// Example: 20543 → 20.5K (decimals = 1), 198000 → 1.98L (decimals = 2).
    static func abbreviatedFloor(_ value: Double, decimals: Int = 2) -> String {
        let absolute = abs(value)
        guard absolute >= 1000 else {
            return formatAbbreviatedNumber(value, maxFractionDigits: max(0, decimals))
        }

        let units: [(threshold: Double, suffix: String)] = [
            (10_000_000, "C"),
            (1_000_000, "M"),
            (100_000, "L"),
            (1_000, "K")
        ]

        guard let unit = units.first(where: { absolute >= $0.threshold }) else {
            return formatAbbreviatedNumber(value, maxFractionDigits: max(0, decimals))
        }

        let digits = max(0, decimals)
        let factor = pow(10.0, Double(digits))
        let scaled = absolute / unit.threshold
        let floored = Foundation.floor(scaled * factor) / factor
        let signedValue = value < 0 ? -floored : floored

        return "\(formatAbbreviatedNumber(signedValue, maxFractionDigits: digits))\(unit.suffix)"
    }

    private static func currencySymbol(for currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol ?? currencyCode
    }

    private static func formatAbbreviatedNumber(_ value: Double, maxFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func fallbackCurrency(_ value: Double, currencyCode: String) -> String {
        "\(currencyCode) \(formatDecimal(value))"
    }
}
