//
//  PrimaryGradient.swift
//  Xpnse
//
//  Created by Gokul C on 10/09/25.
//

import SwiftUI

struct PrimaryGradient: View {
    static let colors: [Color] = [
        Color(red: 0.4, green: 0.2, blue: 0.8),
        Color(red: 0.6, green: 0.3, blue: 0.9),
        Color(red: 0.8, green: 0.4, blue: 1.0)
    ]

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: Self.colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
