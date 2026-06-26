//
//  CategoryColorPickerView.swift
//  Xpnse
//

import SwiftUI

struct CategoryColorPickerView: View {
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                CategoryIconBadge(
                    symbolName: symbolName,
                    colorHex: normalizedSelectedHex,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Text("How this category will look")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }

                Spacer(minLength: 0)
            }

            ColorPicker(
                "Choose a color",
                selection: colorBinding,
                supportsOpacity: false
            )
            .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(XpnseColorKey.whiteWithAlphaFifteen.color)
        .xpnseRoundedCorner(strokeConfig: StrokeConfig(color: .whiteWithAlphaThirty, lineWidth: 2))
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
