//
//  CompactNumberFormatting.swift
//  XpnseShared
//

import Foundation

/// Formats a bare numeric amount into a compact abbreviation (no currency symbol).
protocol CompactNumberFormatting: Sendable {
    func format(_ value: Decimal) -> String
}
