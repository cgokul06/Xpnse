//
//  WidgetStyle.swift
//  XpnseWidgets
//

import SwiftUI
import WidgetKit

enum WidgetStyle {
    static let income = Color(XpnseColorKey.incomePrimary.rawValue)
    static let savings = Color(XpnseColorKey.savingsPrimary.rawValue)
    static let expense = Color(XpnseColorKey.expensePrimary.rawValue)

    static let cornerRadius: CGFloat = 16
    static let borderWidth: CGFloat = 1.5

    static var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    static var primaryText: Color { .primary }
    static var mutedText: Color { .secondary }
    static var elevatedFill: Color { Color.primary.opacity(0.08) }
    static var border: Color { Color.primary.opacity(0.22) }
    static var divider: Color { Color.primary.opacity(0.22) }

    /// Light + Dark variants so Home Screen Dark can swap without re-archiving RGB.
    static let canvas = Color("WidgetCanvas")

    static func outlinedBackground<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        AdaptiveWidgetChrome(content: content)
    }
}

enum WidgetChromeMode {
    static func isTemplate(
        renderingMode: WidgetRenderingMode,
        showsContainerBackground: Bool
    ) -> Bool {
        renderingMode != .fullColor || !showsContainerBackground
    }
}

private struct AdaptiveWidgetChrome<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsContainerBackground

    private var isTemplate: Bool {
        WidgetChromeMode.isTemplate(
            renderingMode: renderingMode,
            showsContainerBackground: showsContainerBackground
        )
    }

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) {
                if isTemplate {
                    Color.clear
                } else {
                    WidgetStyle.canvas
                }
            }
    }
}

/// SF Symbol that stays visible in Clear / Tinted: those modes flatten views to
/// alpha templates, so a white glyph on an opaque badge disappears.
struct WidgetGlyphBadge: View {
    let systemName: String
    var fill: Color? = nil
    var fontSize: CGFloat
    var size: CGFloat
    var padding: CGFloat = 2

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsContainerBackground

    private var isTemplate: Bool {
        WidgetChromeMode.isTemplate(
            renderingMode: renderingMode,
            showsContainerBackground: showsContainerBackground
        )
    }

    var body: some View {
        if isTemplate {
            Image(systemName: systemName)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(Color.primary)
                .widgetAccentable()
                .frame(width: size, height: size)
        } else if let fill {
            Image(systemName: systemName)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .padding(padding)
                .background(Circle().fill(fill))
        } else {
            Image(systemName: systemName)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(WidgetStyle.mutedText)
                .frame(width: size, height: size)
        }
    }
}

extension Color {
    init(widgetHex hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red, green, blue: Double
        switch sanitized.count {
        case 6:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
        default:
            red = 1
            green = 1
            blue = 1
        }

        self.init(red: red, green: green, blue: blue)
    }
}

enum WidgetAbbreviation {
    static func format(_ value: Double) -> String {
        AmountFormatter.abbreviatedFloor(value)
    }
}

struct WidgetSectionHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WidgetStyle.primaryText)
                .widgetAccentable()

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetStyle.mutedText)
                    .widgetAccentable()
            }
        }
    }
}
