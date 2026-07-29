//
//  InsightsGhostView.swift
//  Xpnse
//

import SwiftUI

/// Placeholder layout shown while Insights analytics are calculating.
struct InsightsGhostView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                chartGhost
                cardGhost(lines: 3, barHeights: [12, 12])
                cardGhost(lines: 4, barHeights: [10, 10, 10])
                cardGhost(lines: 3, barHeights: [10, 10])
                cardGhost(lines: 4, barHeights: [8, 8, 8, 8])
                cardGhost(lines: 3, barHeights: [12, 12, 12])
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollDisabled(true)
        .accessibilityLabel(L10n.tr("insights.loading"))
    }

    private var chartGhost: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerGhost(width: 120)

            ZStack(alignment: .bottom) {
                boneRect(cornerRadius: 8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        boneRect(cornerRadius: 4, strong: true)
                            .frame(maxWidth: .infinity)
                            .frame(height: CGFloat(40 + (index % 3) * 28))
                    }
                }
                .padding(16)
            }
        }
        .padding(16)
        .xpnseOutlinedPanel()
    }

    private func cardGhost(lines: Int, barHeights: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            headerGhost(width: CGFloat(100 + lines * 12))
            ForEach(0..<lines, id: \.self) { index in
                HStack {
                    boneRect(cornerRadius: 4)
                        .frame(width: CGFloat(80 + (index % 3) * 24), height: 12)
                    Spacer()
                    boneRect(cornerRadius: 4)
                        .frame(width: 48, height: 12)
                }
                if index < barHeights.count {
                    boneCapsule()
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeights[index])
                }
            }
        }
        .padding(16)
        .xpnseOutlinedPanel()
    }

    private func headerGhost(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            boneRect(cornerRadius: 4, strong: true)
                .frame(width: width, height: 16)
            boneRect(cornerRadius: 4)
                .frame(width: width * 0.7, height: 10)
        }
    }

    private func boneRect(cornerRadius: CGFloat, strong: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(strong ? boneStrong : bone)
            .shimmering(.roundedRect(cornerRadius))
    }

    private func boneCapsule() -> some View {
        Capsule(style: .continuous)
            .fill(bone)
            .shimmering(.capsule)
    }

    private var bone: Color {
        AdaptiveBrandSurface.primaryForeground(for: colorScheme).opacity(
            colorScheme == .dark ? 0.12 : 0.08
        )
    }

    private var boneStrong: Color {
        AdaptiveBrandSurface.primaryForeground(for: colorScheme).opacity(
            colorScheme == .dark ? 0.18 : 0.12
        )
    }
}
