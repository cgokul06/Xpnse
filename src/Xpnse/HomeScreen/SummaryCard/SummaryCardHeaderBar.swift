//
//  SummaryCardHeaderBar.swift
//  Xpnse
//

import SwiftUI

struct SummaryCardHeaderBar: View {
    let title: String
    let flipIconName: String
    let onFlip: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            SummaryCardFlipButton(iconName: flipIconName, action: onFlip)
        }
        .frame(height: SummaryCardMetrics.headerHeight)
    }
}
