//
//  DS+View+Extensions.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

// MARK: - XpnseColorKey Extensions
extension XpnseColorKey {
    var color: Color {
        Color(self.rawValue)
    }
}

// MARK: - ViewModifier Extensions

struct StrokeConfig {
    let color: XpnseColorKey
    let lineWidth: CGFloat

    init(color: XpnseColorKey, lineWidth: CGFloat) {
        self.color = color
        self.lineWidth = lineWidth
    }

    static let `default` = StrokeConfig(color: .clear, lineWidth: 1)
}
