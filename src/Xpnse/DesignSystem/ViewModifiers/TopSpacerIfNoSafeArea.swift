//
//  TopSpacerIfNoSafeArea.swift
//  Xpnse
//
//  Created by Gokul C on 10/09/25.
//

import SwiftUI

struct TopSpacerIfNoSafeArea: ViewModifier {
    var spacing: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if geometry.safeAreaInsets.top == 0 {
                    Spacer().frame(height: spacing)
                }

                content
            }
        }
    }
}
