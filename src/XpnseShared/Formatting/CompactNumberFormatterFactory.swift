//
//  CompactNumberFormatterFactory.swift
//  XpnseShared
//

import Foundation

enum CompactNumberFormatterFactory {
    static func make(style: AmountFormattingStyle) -> any CompactNumberFormatting {
        switch style {
        case .lakhCrore:
            return LakhCroreAmountFormatter()
        case .million:
            return MillionAmountFormatter()
        }
    }

    /// Formatter for the user's saved preference resolved against device locale.
    static func makeResolved() -> any CompactNumberFormatting {
        make(style: NumberFormatPreference.current.resolvedStyle)
    }
}
