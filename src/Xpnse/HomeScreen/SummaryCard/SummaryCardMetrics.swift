//
//  SummaryCardMetrics.swift
//  Xpnse
//

import CoreGraphics

enum SummaryCardMetrics {
    static let height: CGFloat = 188
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 16
    static let headerHeight: CGFloat = 44
    static let sectionSpacing: CGFloat = 12

    static var contentAreaHeight: CGFloat {
        height - (verticalPadding * 2) - headerHeight - sectionSpacing
    }

    static var donutSize: CGFloat {
        min(contentAreaHeight, 100)
    }

    static let cornerRadius: CGFloat = 16
}
