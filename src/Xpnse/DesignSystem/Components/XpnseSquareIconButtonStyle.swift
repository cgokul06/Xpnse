//
//  XpnseSquareIconButtonStyle.swift
//  Xpnse
//
//  Created by Gokul C on 19/05/26.
//

import SwiftUI

enum XpnseBottomBarMetrics {
    static let buttonHeight: CGFloat = 56
}

struct XpnseSquareIconButtonStyle: ButtonStyle {
    let bgColor: XpnseColorKey
    let foregroundColor: XpnseColorKey
    let borderColor: XpnseColorKey
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let isDisabled: Binding<Bool>
    let isLoading: Binding<Bool>

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .bold))
            .frame(
                width: XpnseBottomBarMetrics.buttonHeight,
                height: XpnseBottomBarMetrics.buttonHeight
            )
            .foregroundColor(foregroundColor.color)
            .background(bgColor.color)
            .xpnseRoundedCorner(
                cornerRadius,
                strokeConfig: StrokeConfig(
                    color: borderColor,
                    lineWidth: borderWidth
                )
            )
            .opacity((configuration.isPressed || isDisabled.wrappedValue) ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.default, value: configuration.isPressed)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 8)
            .disabled(isDisabled.wrappedValue || isLoading.wrappedValue)
    }

    static func defaultButton(
        bgColor: XpnseColorKey = .primaryButtonBGColor,
        isDisabled: Binding<Bool> = .constant(false),
        isLoading: Binding<Bool> = .constant(false)
    ) -> Self {
        Self(
            bgColor: bgColor,
            foregroundColor: .white,
            borderColor: .clear,
            cornerRadius: 16,
            borderWidth: 2,
            isDisabled: isDisabled,
            isLoading: isLoading
        )
    }
}
