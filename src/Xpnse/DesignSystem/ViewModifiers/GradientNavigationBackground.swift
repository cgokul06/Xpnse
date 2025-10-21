//
//  GradientNavigationBackground.swift
//  Xpnse
//
//  Created by Gokul C on 10/09/25.
//

import SwiftUI

struct GradientNavigationBackground: ViewModifier {
    func body(content: Content) -> some View {
        NavigationView {
            ZStack {
                PrimaryGradient()
                    .ignoresSafeArea()
                content
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
