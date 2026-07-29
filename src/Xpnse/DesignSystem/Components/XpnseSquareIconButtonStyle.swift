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
        let disabled = isDisabled.wrappedValue
        let showBrandDisabled = usesBrandGradient && disabled

        configuration.label
            .font(.system(size: 20, weight: .bold))
            .frame(
                width: XpnseBottomBarMetrics.buttonHeight,
                height: XpnseBottomBarMetrics.buttonHeight
            )
            .foregroundColor(
                showBrandDisabled
                    ? XpnseColorKey.secondaryButtonDisabledText.color
                    : foregroundColor.color
            )
            .background(backgroundFill(disabled: disabled))
            .xpnseRoundedCorner(
                cornerRadius,
                strokeConfig: StrokeConfig(
                    color: .clear,
                    lineWidth: borderWidth
                )
            )
            .opacity(pressedOpacity(configuration: configuration, disabled: disabled))
            .scaleEffect(configuration.isPressed && !disabled ? 0.9 : 1)
            .animation(.default, value: configuration.isPressed)
            .shadow(
                color: shadowColor(disabled: disabled),
                radius: usesBrandGradient && !disabled
                    ? XpnsePrimaryButtonChrome.shadowRadius
                    : 10,
                x: 0,
                y: usesBrandGradient && !disabled
                    ? XpnsePrimaryButtonChrome.shadowY
                    : 8
            )
            .disabled(disabled || isLoading.wrappedValue)
    }

    @ViewBuilder
    private func backgroundFill(disabled: Bool) -> some View {
        if usesBrandGradient {
            if disabled {
                // Disabled icon button: #103654 background, #5D7B91 icon.
                XpnseColorKey.secondaryButtonBackground.color
            } else {
                XpnsePrimaryButtonChrome.gradient
            }
        } else {
            bgColor.color
        }
    }

    private func pressedOpacity(configuration: Configuration, disabled: Bool) -> Double {
        if usesBrandGradient {
            if disabled { return 1 }
            return configuration.isPressed ? 0.6 : 1
        }
        return (configuration.isPressed || disabled) ? 0.6 : 1
    }

    private func shadowColor(disabled: Bool) -> Color {
        if usesBrandGradient {
            return disabled ? .clear : XpnsePrimaryButtonChrome.shadowColor
        }
        return Color.black.opacity(0.2)
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
