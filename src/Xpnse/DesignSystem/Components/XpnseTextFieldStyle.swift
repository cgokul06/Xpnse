//
//  XpnseTextFieldStyle.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct XpnseTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(XpnseColorKey.whiteWithAlphaFifteen.color)
            .xpnseRoundedCorner(strokeConfig: StrokeConfig(color: .whiteWithAlphaThirty, lineWidth: 2))
    }
}
