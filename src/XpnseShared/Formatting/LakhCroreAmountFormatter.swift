//
//  LakhCroreAmountFormatter.swift
//  XpnseShared
//

import Foundation

/// Compact notation using K (thousand), L (lakh), and Cr (crore).
struct LakhCroreAmountFormatter: CompactNumberFormatting {
    func format(_ value: Decimal) -> String {
        let absolute = abs(value)
        if absolute < CompactNumberFormattingSupport.thousand {
            return CompactNumberFormattingSupport.formatPlain(value)
        }
        if absolute < CompactNumberFormattingSupport.lakh {
            return CompactNumberFormattingSupport.formatScaled(
                value,
                divisor: CompactNumberFormattingSupport.thousand,
                suffix: "K"
            )
        }
        if absolute < CompactNumberFormattingSupport.crore {
            return CompactNumberFormattingSupport.formatScaled(
                value,
                divisor: CompactNumberFormattingSupport.lakh,
                suffix: "L"
            )
        }
        return CompactNumberFormattingSupport.formatScaled(
            value,
            divisor: CompactNumberFormattingSupport.crore,
            suffix: "Cr"
        )
    }
}
