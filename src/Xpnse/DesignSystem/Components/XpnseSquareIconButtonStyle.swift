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
    let usesBrandGradient: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .bold))
            .frame(
                width: XpnseBottomBarMetrics.buttonHeight,
                height: XpnseBottomBarMetrics.buttonHeight
            )
            .foregroundColor(foregroundColor.color)
            .background(backgroundFill)
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
            .shadow(
                color: usesBrandGradient
                    ? XpnsePrimaryButtonChrome.shadowColor
                    : Color.black.opacity(0.2),
                radius: usesBrandGradient
                    ? XpnsePrimaryButtonChrome.shadowRadius
                    : 10,
                x: 0,
                y: usesBrandGradient ? XpnsePrimaryButtonChrome.shadowY : 8
            )
            .disabled(isDisabled.wrappedValue || isLoading.wrappedValue)
    }

    @ViewBuilder
    private var backgroundFill: some View {
        if usesBrandGradient {
            XpnsePrimaryButtonChrome.gradient
        } else {
            bgColor.color
        }
    }

    static func defaultButton(
        bgColor: XpnseColorKey = .primaryButtonBGColor,
        isDisabled: Binding<Bool> = .constant(false),
        isLoading: Binding<Bool> = .constant(false)
    ) -> Self {
        let usesGradient = bgColor == .primaryButtonBGColor
        return Self(
            bgColor: bgColor,
            foregroundColor: .white,
            borderColor: .clear,
            cornerRadius: 16,
            borderWidth: 2,
            isDisabled: isDisabled,
            isLoading: isLoading,
            usesBrandGradient: usesGradient
        )
    }
}
