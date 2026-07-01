//
//  Double+Extensions.swift
//  Xpnse
//
//  Created by Gokul C on 09/05/26.
//

import Foundation

extension Double {
    /// Formats large numbers using floor-based abbreviated units.
    /// Units follow: K (thousand), L (lakh), M (million), C (crore).
    /// Example: 20543 -> 20.5K (for decimals = 1), 9812345 -> 98.1L.
    func abbreviatedFloor(decimals: Int = 2) -> String {
        let absolute = abs(self)
        guard absolute >= 1000 else {
            return Self.formatNumber(self, maxFractionDigits: max(0, decimals))
        }

        let units: [(threshold: Double, suffix: String)] = [
            (10_000_000, "C"),
            (1_000_000, "M"),
            (100_000, "L"),
            (1_000, "K")
        ]

        guard let unit = units.first(where: { absolute >= $0.threshold }) else {
            return Self.formatNumber(self, maxFractionDigits: max(0, decimals))
        }

        let digits = max(0, decimals)
        let factor = pow(10.0, Double(digits))
        let scaled = absolute / unit.threshold
        let floored = Foundation.floor(scaled * factor) / factor
        let signedValue = self < 0 ? -floored : floored

        return "\(Self.formatNumber(signedValue, maxFractionDigits: digits))\(unit.suffix)"
    }

    private static func formatNumber(_ value: Double, maxFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = maxFractionDigits >= 2 ? 2 : 0
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

