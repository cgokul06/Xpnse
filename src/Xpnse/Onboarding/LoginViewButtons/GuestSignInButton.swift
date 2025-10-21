//
//  GuestSignInButton.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct GuestSignInButton<AuthManager: AuthManagerProtocol>: View {
    @ObservedObject var authManager: AuthManager

    var body: some View {
        Button(action: {
            Task {
                await authManager.signInAnonymously()
            }
        }) {
            HStack {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("Continue as Guest")
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
        .padding(.top, 8)
        .disabled(authManager.isLoading)
        .opacity(authManager.isLoading ? 0.6 : 1)
    }
}
