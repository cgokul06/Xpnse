//
//  CategoryColorPickerView.swift
//  Xpnse
//

import SwiftUI

struct CategoryColorPickerView: View {
    @Binding var selectedColorHex: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: selectedColorHex))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    )

                Text(selectedColorHex.uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(CategoryColorPalette.colors, id: \.self) { hex in
                    Button {
                        selectedColorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 36, height: 36)
                            .overlay {
                                if CategoryColorPalette.normalizedHex(selectedColorHex) == hex {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .shadow(radius: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
