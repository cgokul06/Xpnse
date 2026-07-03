//
//  AdaptiveBrandSurface.swift
//  Xpnse
//

import SwiftUI

/// POC: replace the purple brand canvas with white (light) and black (dark).
enum AdaptiveBrandSurface {
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }

    static func primaryForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    static func mutedForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.55)
    }

    static func fieldBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.05)
    }

    static func fieldBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.12)
    }

    static func elevatedSurfaceBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    static func segmentTrackBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    static func dropdownExpandedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.6, green: 0.3, blue: 0.9)
            : Color.black.opacity(0.08)
    }

    static func rowBackground(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(emphasized ? 0.2 : 0.1)
        }
        return Color.black.opacity(emphasized ? 0.1 : 0.05)
    }
}

struct XpnseAdaptiveForeground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var muted: Bool = false

    func body(content: Content) -> some View {
        content.foregroundStyle(
            muted
                ? AdaptiveBrandSurface.mutedForeground(for: colorScheme)
                : AdaptiveBrandSurface.primaryForeground(for: colorScheme)
        )
    }
}

extension View {
    func xpnseAdaptiveForeground(muted: Bool = false) -> some View {
        modifier(XpnseAdaptiveForeground(muted: muted))
    }
}
