//
//  SummaryCardFlipButton.swift
//  Xpnse
//

import SwiftUI
import UIKit

struct SummaryCardFlipButton: View {
    let iconName: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .medium))
                .xpnseAdaptiveForeground()
                .frame(width: 36, height: 36)
                .background(AdaptiveBrandSurface.rowBackground(for: colorScheme))
                .clipShape(Circle())
        }
    }
}
