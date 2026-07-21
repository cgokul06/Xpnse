//
//  SummaryCardShell.swift
//  Xpnse
//

import SwiftUI

struct SummaryCardShell<Content: View>: View {
    let title: String
    let flipIconName: String
    let onFlip: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: SummaryCardMetrics.sectionSpacing) {
            SummaryCardHeaderBar(
                title: title,
                flipIconName: flipIconName,
                onFlip: onFlip
            )

            content()
                .frame(
                    maxWidth: .infinity,
                    minHeight: SummaryCardMetrics.contentAreaHeight,
                    maxHeight: SummaryCardMetrics.contentAreaHeight,
                    alignment: .topLeading
                )
        }
        .padding(.horizontal, SummaryCardMetrics.horizontalPadding)
        .padding(.vertical, SummaryCardMetrics.verticalPadding)
        .frame(height: SummaryCardMetrics.height, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
        .xpnseOutlinedPanel()
    }
}
