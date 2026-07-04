//
//  DisableBouncesModifier.swift
//  Xpnse
//

import SwiftUI
import UIKit

struct DisableBouncesModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                UIScrollView.appearance().bounces = false
            }
            .onDisappear {
                UIScrollView.appearance().bounces = true
            }
    }
}

extension View {
    func disableBounces() -> some View {
        modifier(DisableBouncesModifier())
    }
}
