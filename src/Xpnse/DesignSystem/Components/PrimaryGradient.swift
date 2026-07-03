//
//  PrimaryGradient.swift
//  Xpnse
//
//  Created by Gokul C on 10/09/25.
//

import SwiftUI

struct PrimaryGradient: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Legacy purple gradient kept for reference while the adaptive POC is evaluated.
    static let legacyPurpleColors: [Color] = [
        Color(red: 0.4, green: 0.2, blue: 0.8),
        Color(red: 0.6, green: 0.3, blue: 0.9),
        Color(red: 0.8, green: 0.4, blue: 1.0)
    ]

    var body: some View {
        AdaptiveBrandSurface.background(for: colorScheme)
            .ignoresSafeArea()
    }
}
