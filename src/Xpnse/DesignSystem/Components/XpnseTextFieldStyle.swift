//
//  XpnseTextFieldStyle.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct XpnseTextFieldStyle: TextFieldStyle {
    @Environment(\.colorScheme) private var colorScheme

    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(AdaptiveBrandSurface.fieldBackground(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AdaptiveBrandSurface.fieldBorder(for: colorScheme), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
