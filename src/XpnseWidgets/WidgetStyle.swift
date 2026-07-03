//
//  WidgetStyle.swift
//  XpnseWidgets
//

import SwiftUI
import WidgetKit

enum WidgetStyle {
    static let summaryCard = Color(red: 0x47 / 255, green: 0x54 / 255, blue: 0xD3 / 255)
    static let income = Color(XpnseColorKey.incomePrimary.rawValue)
    static let savings = Color(XpnseColorKey.savingsPrimary.rawValue)
    static let expense = Color(XpnseColorKey.expensePrimary.rawValue)
    static let secondaryButton = Color(red: 0x5E / 255, green: 0x5C / 255, blue: 0xE6 / 255)
    static let mutedText = Color.white.opacity(0.72)
    static let divider = Color.white.opacity(0.22)

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.4, green: 0.2, blue: 0.8),
                Color(red: 0.6, green: 0.3, blue: 0.9),
                Color(red: 0.8, green: 0.4, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func cardBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .containerBackground(for: .widget) {
                summaryCard
            }
    }

    static func gradientBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .containerBackground(for: .widget) {
                primaryGradient
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
        let absolute = abs(value)
        guard absolute >= 1000 else {
            return String(format: "%.2f", value)
        }

        let units: [(Double, String)] = [
            (10_000_000, "C"),
            (1_000_000, "M"),
            (100_000, "L"),
            (1_000, "K")
        ]

        guard let unit = units.first(where: { absolute >= $0.0 }) else {
            return String(format: "%.2f", value)
        }

        let scaled = absolute / unit.0
        let floored = floor(scaled * 100) / 100
        let signed = value < 0 ? -floored : floored
        return String(format: "%.2f%@", signed, unit.1)
    }
}

struct WidgetSectionHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetStyle.mutedText)
            }
        }
    }
}
