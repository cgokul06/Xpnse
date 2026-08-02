//
//  AmountFormattingStyle.swift
//  XpnseShared
//

import Foundation

/// Compact number abbreviation style (independent of currency formatting).
enum AmountFormattingStyle: String, CaseIterable, Sendable {
    case lakhCrore
    case million
}
