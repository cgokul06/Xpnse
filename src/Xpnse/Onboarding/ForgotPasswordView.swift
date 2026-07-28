//
//  ForgotPasswordView.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct ForgotPasswordView<AuthManager: AuthManagerProtocol>: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authCoordinator: NavigationCoordinator<AuthRoute>
    
    @State private var email = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.4, green: 0.2, blue: 0.8),
                        Color(red: 0.6, green: 0.3, blue: 0.9),
                        Color(red: 0.8, green: 0.4, blue: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("auth.reset_password")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("auth.reset_subtitle")
                        .font(.body)
                        .foregroundColor(XpnseColorKey.white.color)
                        .multilineTextAlignment(.center)
                    
                    TextField("auth.email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .xpnseStyledTextField()

                    Button(action: {
                        Task {
                            await authManager.resetPassword(email: email)
                            if authManager.errorMessage == nil {
                                authCoordinator.dismissSheet()
                            }
                        }
                    }) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: XpnseColorKey.white.color))
                                    .scaleEffect(0.8)
                            }
                            Text("auth.send_reset")
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(
                        XpnsePrimaryButtonStyle.defaultButton(
                            isDisabled: Binding(get: {
                                email.isEmpty
                            }, set: {_ in }),
                            isLoading: Binding(get: {
                                authManager.isLoading
                            }, set: {_ in })
                        )
                    )

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }, label: {
                        Image(systemName: "xmark")
                            .bold()
                            .padding(.all, 8)
                    })
                    .foregroundStyle(Color.black)
                }
            }
            .alert("common.error", isPresented: .constant(authManager.errorMessage != nil)) {
                Button("common.ok") {
                    authManager.clearError()
                }
            } message: {
                Text(authManager.errorMessage ?? "")
            }
        }
        .navigationBarBackButtonHidden()
    }
}
