//
//  XpnseSecondaryButtonStyle.swift
//  Xpnse
//

import SwiftUI

struct XpnseSecondaryButtonStyle: ButtonStyle {
    let bgColor: XpnseColorKey
    let foregroundColor: XpnseColorKey
    let borderColor: XpnseColorKey
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let isDisabled: Binding<Bool>
    let isLoading: Binding<Bool>

    func makeBody(configuration: Configuration) -> some View {
        let disabled = isDisabled.wrappedValue

        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .foregroundColor(
                disabled
                    ? XpnseColorKey.secondaryButtonDisabledText.color
                    : foregroundColor.color
            )
            .background(
                disabled
                    ? XpnseColorKey.secondaryButtonDisabledBG.color
                    : bgColor.color
            )
            .xpnseRoundedCorner(
                cornerRadius,
                strokeConfig: StrokeConfig(
                    color: disabled
                        ? .secondaryButtonDisabledBorder
                        : borderColor,
                    lineWidth: borderWidth
                )
            )
            .opacity(configuration.isPressed && !disabled ? 0.6 : 1)
            .scaleEffect(configuration.isPressed && !disabled ? 0.9 : 1)
            .animation(.default, value: configuration.isPressed)
            .disabled(disabled || isLoading.wrappedValue)
    }

    /// Enabled: background `#103654`, border & text `#59C8A8`.
    /// Disabled: background `#0D2B42`, border `#284B63`, text `#5D7B91`.
    static func defaultButton(
        isDisabled: Binding<Bool> = .constant(false),
        isLoading: Binding<Bool> = .constant(false)
    ) -> Self {
        Self(
            bgColor: .secondaryButtonBackground,
            foregroundColor: .secondaryButtonAccent,
            borderColor: .secondaryButtonAccent,
            cornerRadius: 16,
            borderWidth: 1.5,
            isDisabled: isDisabled,
            isLoading: isLoading
        )
    }
}
