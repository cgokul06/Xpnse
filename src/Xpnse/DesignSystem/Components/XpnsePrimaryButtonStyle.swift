//
//  XpnsePrimaryButtonStyle.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

enum XpnsePrimaryButtonChrome {
    /// Enabled: #84E4C5 → #39B18F
    static let gradient = LinearGradient(
        colors: [
            XpnseColorKey.primaryButtonGradientTop.color,
            XpnseColorKey.primaryButtonBGColor.color
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Mint shadow: #39B18F @ 18% opacity, blur 18.
    static let shadowColor = XpnseColorKey.primaryButtonBGColor.color.opacity(0.18)
    static let shadowRadius: CGFloat = 18
    static let shadowY: CGFloat = 8
}

struct XpnsePrimaryButtonStyle: ButtonStyle {
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
            .padding(.horizontal, 8)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .foregroundColor(
                showBrandDisabled
                    ? XpnseColorKey.primaryButtonDisabledText.color
                    : foregroundColor.color
            )
            .background(backgroundFill(disabled: disabled))
            .xpnseRoundedCorner(
                cornerRadius,
                strokeConfig: StrokeConfig(
                    color: showBrandDisabled
                        ? .primaryButtonDisabledBorder
                        : borderColor,
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
                XpnseColorKey.primaryButtonDisabledBG.color
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
