//
//  MillionAmountFormatter.swift
//  XpnseShared
//

import Foundation

/// Compact notation using K, M, B, and T.
struct MillionAmountFormatter: CompactNumberFormatting {
    func format(_ value: Decimal) -> String {
        let absolute = abs(value)
        if absolute < CompactNumberFormattingSupport.thousand {
            return CompactNumberFormattingSupport.formatPlain(value)
        }
        if absolute < CompactNumberFormattingSupport.million {
            return CompactNumberFormattingSupport.formatScaled(
                value,
                divisor: CompactNumberFormattingSupport.thousand,
                suffix: "K"
            )
        }
        if absolute < CompactNumberFormattingSupport.billion {
            return CompactNumberFormattingSupport.formatScaled(
                value,
                divisor: CompactNumberFormattingSupport.million,
                suffix: "M"
            )
        }
        if absolute < CompactNumberFormattingSupport.trillion {
            return CompactNumberFormattingSupport.formatScaled(
                value,
                divisor: CompactNumberFormattingSupport.billion,
                suffix: "B"
            )
        }
        return CompactNumberFormattingSupport.formatScaled(
            value,
            divisor: CompactNumberFormattingSupport.trillion,
            suffix: "T"
        )
    }
}
