//
//  XpnsePrimaryButtonStyle.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

enum XpnsePrimaryButtonChrome {
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
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
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
