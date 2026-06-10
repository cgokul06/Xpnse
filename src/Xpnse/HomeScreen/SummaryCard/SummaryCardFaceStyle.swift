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
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 8)
    }
}
