//
//  View+CompactAmountAccessibility.swift
//  XpnseShared
//

import SwiftUI

extension View {
    /// VoiceOver announces the exact currency amount instead of the compact abbreviation.
    func accessibilityExactAmount(_ value: Double, currencyCode: String) -> some View {
        accessibilityLabel(AmountFormatter.format(value, currencyCode: currencyCode))
    }
}
