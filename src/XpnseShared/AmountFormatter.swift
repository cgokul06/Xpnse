//
//  AmountFormatter.swift
//  XpnseShared
//

import Foundation

enum AmountFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func format(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func format(_ value: Decimal) -> String {
        format((value as NSDecimalNumber).doubleValue)
    }

    /// Formats large numbers using floor-based abbreviated units (K, L, M, C).
    static func abbreviatedFloor(_ value: Double, decimals: Int = 2) -> String {
        let absolute = abs(value)
        guard absolute >= 1000 else {
            return formatNumber(value, maxFractionDigits: max(0, decimals))
        }

        let units: [(threshold: Double, suffix: String)] = [
            (10_000_000, "C"),
            (1_000_000, "M"),
            (100_000, "L"),
            (1_000, "K")
        ]

        guard let unit = units.first(where: { absolute >= $0.threshold }) else {
            return formatNumber(value, maxFractionDigits: max(0, decimals))
        }

        let digits = max(0, decimals)
        let factor = pow(10.0, Double(digits))
        let scaled = absolute / unit.threshold
        let floored = Foundation.floor(scaled * factor) / factor
        let signedValue = value < 0 ? -floored : floored

        return "\(formatNumber(signedValue, maxFractionDigits: digits))\(unit.suffix)"
    }

    private static func formatNumber(_ value: Double, maxFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = maxFractionDigits >= 2 ? 2 : 0
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}
