//
//  CategoryColorPickerView.swift
//  Xpnse
//

import SwiftUI

struct CategoryColorPickerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedColorHex: String
    var symbolName: String = "tag.fill"

    private var normalizedSelectedHex: String {
        let normalized = CategoryColorPalette.normalizedHex(selectedColorHex)
        guard CategoryColorPalette.isValid(normalized) else {
            return CategoryColorPalette.defaultHex
        }
        return normalized
    }

    var body: some View {
        ColorPicker(selection: colorBinding, supportsOpacity: false) {
            HStack(spacing: 12) {
                CategoryIconBadge(
                    symbolName: symbolName,
                    colorHex: normalizedSelectedHex,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview")
                        .font(.system(size: 14, weight: .semibold))
                        .xpnseAdaptiveForeground()
                    Text("Tap to choose a color")
                        .font(.system(size: 13, weight: .medium))
                        .xpnseAdaptiveForeground(muted: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(AdaptiveBrandSurface.fieldBackground(for: colorScheme))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AdaptiveBrandSurface.fieldBorder(for: colorScheme), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: normalizedSelectedHex) },
            set: { newColor in
                selectedColorHex = CategoryColorPalette.normalizedHex(newColor.hexString)
            }
        )
    }
}
