//
//  GoogleSignInButton.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct GoogleSignInButton<AuthManager: AuthManagerProtocol>: View {
    @ObservedObject var authManager: AuthManager

    var body: some View {
        Button(action: {
            Task {
                await authManager.signInWithGoogle()
            }
        }) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.white)
                
                if authManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Continue with Google")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .xpnseRoundedCorner()
        }
        .disabled(authManager.isLoading)
    }
}
