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

    /// Uses App Group preference synced from the main app. WidgetKit's own
    /// `colorScheme` / `systemBackground` often follow wallpaper luminance and
    /// can stay dark while the phone is in Light Mode.
    static var prefersDark: Bool {
        WidgetAppearanceStore.prefersDark
    }

    static func canvas(for colorScheme: ColorScheme) -> Color {
        prefersDark
            ? Color(red: 0, green: 0, blue: 0)
            : Color(red: 1, green: 1, blue: 1)
    }

    static func primaryText(for colorScheme: ColorScheme) -> Color {
        prefersDark ? .white : .black
    }

    static func mutedText(for colorScheme: ColorScheme) -> Color {
        prefersDark
            ? Color.white.opacity(0.72)
            : Color.black.opacity(0.55)
    }

    static func elevatedFill(for colorScheme: ColorScheme) -> Color {
        prefersDark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.04).opacity(0.55)
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        prefersDark ? Color.white.opacity(0.3) : Color.black.opacity(0.12)
    }

    static func divider(for colorScheme: ColorScheme) -> Color {
        prefersDark ? Color.white.opacity(0.22) : Color.black.opacity(0.12)
    }

    /// Full-bleed adaptive canvas matching the in-app surfaces (no inset border).
    static func outlinedBackground<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        AdaptiveWidgetChrome(content: content)
    }
}

private struct AdaptiveWidgetChrome<Content: View>: View {
    @ViewBuilder let content: () -> Content

    private var prefersDark: Bool {
        WidgetAppearanceStore.prefersDark
    }

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) {
                prefersDark
                    ? Color(red: 0, green: 0, blue: 0)
                    : Color(red: 1, green: 1, blue: 1)
            }
            .environment(\.colorScheme, prefersDark ? .dark : .light)
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
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WidgetStyle.primaryText(for: colorScheme))

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetStyle.mutedText(for: colorScheme))
            }
        }
    }
}
