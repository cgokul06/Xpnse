//
//  View+ViewModifier.swift
//  Xpnse
//
//  Created by Gokul C on 10/09/25.
//

import SwiftUI

extension View {
    func xpnseRoundedCorner(
        _ radius: CGFloat = 16,
        strokeConfig: StrokeConfig = .default
    ) -> some View {
        self
            .modifier(XpnseRoundedCorner(radius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(strokeConfig.color.color, lineWidth: strokeConfig.lineWidth)
            )
    }

    func topSpacingIfNoSafeArea(_ spacing: CGFloat = 24) -> some View {
        self.modifier(TopSpacerIfNoSafeArea(spacing: spacing))
    }

    func gradientNavigationBackground() -> some View {
        self.modifier(GradientNavigationBackground())
    }
}
