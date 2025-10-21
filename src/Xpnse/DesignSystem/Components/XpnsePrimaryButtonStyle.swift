//
//  XpnsePrimaryButtonStyle.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct XpnsePrimaryButtonStyle: ButtonStyle {
    let bgColor: XpnseColorKey
    let foregroundColor: XpnseColorKey
    let borderColor: XpnseColorKey
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let isDisabled: Binding<Bool>
    let isLoading: Binding<Bool>

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
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
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.default, value: configuration.isPressed)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 8)
            .disabled(isDisabled.wrappedValue || isLoading.wrappedValue)
    }

    static func defaultButton(isDisabled: Binding<Bool> = .constant(false), isLoading: Binding<Bool> = .constant(false)) -> Self {
        Self(
            bgColor: .primaryButtonBGColor,
            foregroundColor: .white,
            borderColor: .clear,
            cornerRadius: 16,
            borderWidth: 2,
            isDisabled: isDisabled,
            isLoading: isLoading
        )
    }
}
