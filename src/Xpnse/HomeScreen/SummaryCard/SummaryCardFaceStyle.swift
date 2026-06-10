//
//  SummaryCardFaceStyle.swift
//  Xpnse
//

import SwiftUI

extension View {
    func summaryCardFaceBackground() -> some View {
        background(
            XpnseColorKey.summaryCard.color,
            in: RoundedRectangle(cornerRadius: SummaryCardMetrics.cornerRadius)
        )
    }

    func summaryCardShadow() -> some View {
        compositingGroup()
            .shadow(color: .black.opacity(0.14), radius: 2, x: 0, y: 2)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 6)
    }
}
