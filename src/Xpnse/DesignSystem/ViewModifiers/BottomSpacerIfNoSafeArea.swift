//
//  BottomSpacerIfNoSafeArea.swift
//  Xpnse
//
//  Created by Gokul C on 22/10/25.
//

import SwiftUI

import SwiftUI

struct BottomSpacerIfNoSafeArea: ViewModifier {
    @State private var bottomInset: CGFloat = 0
    var spacing: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: SafeAreaInsetsKey.self, value: geometry.safeAreaInsets)
                }
            )
            .onPreferenceChange(SafeAreaInsetsKey.self) { insets in
                self.bottomInset = insets.bottom
            }
            .padding(.bottom, bottomInset == 0 ? spacing : 0)
    }
}

private struct SafeAreaInsetsKey: PreferenceKey {
    static var defaultValue: EdgeInsets = .init()
    static func reduce(value: inout EdgeInsets, nextValue: () -> EdgeInsets) {
        value = nextValue()
    }
}
