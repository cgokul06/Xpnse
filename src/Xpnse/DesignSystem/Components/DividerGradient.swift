//
//  DividerGradient.swift
//  Xpnse
//
//  Created by Gokul C on 10/06/26.
//

import SwiftUI

struct DividerGradient: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let background = AdaptiveBrandSurface.background(for: colorScheme)

        LinearGradient(
            gradient: Gradient(colors: [
                background.opacity(0.2),
                background.opacity(0.75)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
