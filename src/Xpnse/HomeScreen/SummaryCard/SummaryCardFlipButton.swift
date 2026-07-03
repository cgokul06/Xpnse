//
//  SummaryCardFlipButton.swift
//  Xpnse
//

import SwiftUI
import UIKit

struct SummaryCardFlipButton: View {
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(XpnseColorKey.transactionsButton.color)
                .clipShape(Circle())
        }
    }
}
