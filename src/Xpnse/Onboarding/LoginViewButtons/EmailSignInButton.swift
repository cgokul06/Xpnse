//
//  EmailSignInButton.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct EmailSignInButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text("Continue with Email")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                XpnseColorKey.whiteWithAlphaFifteen.color
            )
            .xpnseRoundedCorner(
                strokeConfig: StrokeConfig(
                    color: .whiteWithAlphaThirty,
                    lineWidth: 2
                )
            )
        }
    }
}

#Preview {
    EmailSignInButton(action: {})
}
