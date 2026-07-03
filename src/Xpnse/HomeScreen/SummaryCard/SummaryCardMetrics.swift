//
//  SummaryCardMetrics.swift
//  Xpnse
//

import CoreGraphics

enum SummaryCardMetrics {
    static let height: CGFloat = 164
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 12
    static let headerHeight: CGFloat = 36
    static let sectionSpacing: CGFloat = 8

    /// Height of the large balance amount on the balance card face.
    static let balanceAmountHeight: CGFloat = 34
    /// Height of the compact savings/expense row on the balance card face.
    static let compactRowHeight: CGFloat = 36

    static var contentAreaHeight: CGFloat {
        height - (verticalPadding * 2) - headerHeight - sectionSpacing
    }

    /// Fixed gap between the balance amount and the bottom stats row.
    static var balanceToRowSpacing: CGFloat {
        contentAreaHeight - balanceAmountHeight - compactRowHeight
    }

    /// Donut fills the content area so its bottom aligns with the stats row bottom.
    static var donutSize: CGFloat {
        contentAreaHeight
    }

    static let cornerRadius: CGFloat = 16
}
