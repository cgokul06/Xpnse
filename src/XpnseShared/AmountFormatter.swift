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
}
