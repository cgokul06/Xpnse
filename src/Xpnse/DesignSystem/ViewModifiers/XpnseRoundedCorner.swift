//
//  XpnseRoundedCorner.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct XpnseRoundedCorner: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        return content
            .clipShape(RoundedRectangle(cornerRadius: self.radius))
    }
}
