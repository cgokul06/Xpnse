//
//  XpnseTextFieldStyle.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct XpnseTextFieldStyle: TextFieldStyle {
    var isError: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(AdaptiveBrandSurface.fieldBackground(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var borderColor: Color {
        isError
            ? AdaptiveBrandSurface.fieldErrorBorder
            : AdaptiveBrandSurface.fieldBorder(for: colorScheme)
    }
}

private struct XpnseTextFieldErrorCaption: ViewModifier {
    let message: String?

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content
            if let message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AdaptiveBrandSurface.fieldErrorBorder)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("textFieldError")
            }
        }
    }
}

extension View {
    /// App-wide text field chrome: optional red border + error caption directly below.
    func xpnseStyledTextField(errorMessage: String? = nil) -> some View {
        let hasError = !(errorMessage ?? "").isEmpty
        return self
            .textFieldStyle(XpnseTextFieldStyle(isError: hasError))
            .modifier(XpnseTextFieldErrorCaption(message: errorMessage))
    }
}
