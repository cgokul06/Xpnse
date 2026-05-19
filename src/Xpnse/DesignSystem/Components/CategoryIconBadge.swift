//
//  CategoryIconBadge.swift
//  Xpnse
//

import SwiftUI

struct CategoryIconBadge: View {
    let symbolName: String
    let colorHex: String
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: size, height: size)
            Image(systemName: symbolName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

extension CategoryDefinition {
    @ViewBuilder
    var iconBadge: some View {
        CategoryIconBadge(symbolName: symbolName, colorHex: colorHex)
    }
}
