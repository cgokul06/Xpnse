//
//  XpnseOutlinedPanel.swift
//  Xpnse
//

import SwiftUI

enum XpnseOutlinedPanelMetrics {
    static let cornerRadius: CGFloat = 16
    static let borderWidth: CGFloat = 1.5
    static let titleSubtitleSpacing: CGFloat = 2
    static let headerToContentSpacing: CGFloat = 12

    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

struct XpnsePanelHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: XpnseOutlinedPanelMetrics.titleSubtitleSpacing) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .xpnseAdaptiveForeground()

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .xpnseAdaptiveForeground(muted: true)
            }
        }
    }
}

private struct XpnseOutlinedPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    private var borderColor: Color {
        AdaptiveBrandSurface.fieldBorder(for: colorScheme)
    }

    private var fillColor: Color {
        // Slight lift so the shadow reads without returning to a tinted card.
        AdaptiveBrandSurface.elevatedSurfaceBackground(for: colorScheme).opacity(
            colorScheme == .dark ? 1 : 0.55
        )
    }

    func body(content: Content) -> some View {
        content
            .background {
                XpnseOutlinedPanelMetrics.shape
                    .fill(fillColor)
            }
            .overlay {
                XpnseOutlinedPanelMetrics.shape
                    .strokeBorder(borderColor, lineWidth: XpnseOutlinedPanelMetrics.borderWidth)
            }
            .clipShape(XpnseOutlinedPanelMetrics.shape)
            .compositingGroup()
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.10), radius: 2, x: 0, y: 1)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 10, x: 0, y: 6)
    }
}

extension View {
    /// Soft continuous panel with adaptive border + shadow — Insights chart framing language.
    func xpnseOutlinedPanel() -> some View {
        modifier(XpnseOutlinedPanelModifier())
    }
}
