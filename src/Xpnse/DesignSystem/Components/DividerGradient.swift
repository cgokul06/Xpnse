//
//  DividerGradient.swift
//  Xpnse
//
//  Created by Gokul C on 10/06/26.
//

import SwiftUI

struct DividerGradient: View {
    static let colors: [Color] = [
        Color(red: 0.8, green: 0.4, blue: 1.0).opacity(0.2),
        Color(red: 0.4, green: 0.2, blue: 0.8).opacity(0.75)
    ]

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: Self.colors),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
