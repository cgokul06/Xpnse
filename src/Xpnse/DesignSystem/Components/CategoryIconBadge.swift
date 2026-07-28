//
//  CategoryIconBadge.swift
//  Xpnse
//

import SwiftUI

struct CategoryIconBadge: View {
    let symbolName: String
    let colorHex: String
    var size: CGFloat = 28
    /// When false, renders a plain emoji / SF Symbol with no colored circle.
    var showsColorBackground: Bool = true

    var body: some View {
        ZStack {
            if showsColorBackground {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: size, height: size)
            }

            if CategoryIcon.isEmojiIcon(symbolName) {
                Text(symbolName)
                    .font(.system(size: showsColorBackground ? size * 0.55 : size * 0.9))
            } else {
                Image(systemName: symbolName)
                    .font(.system(
                        size: showsColorBackground ? size * 0.42 : size * 0.72,
                        weight: .semibold
                    ))
                    .foregroundColor(showsColorBackground ? .white : Color(hex: colorHex))
            }
        }
        .frame(width: size, height: size)
    }
}

extension CategoryDefinition {
    @ViewBuilder
    var iconBadge: some View {
        CategoryIconBadge(symbolName: symbolName, colorHex: colorHex)
    }
}
