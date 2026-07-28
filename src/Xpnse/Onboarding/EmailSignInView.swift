//
//  EmailSignInView.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct EmailSignInView<AuthManager: AuthManagerProtocol>: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authCoordinator: NavigationCoordinator<AuthRoute>
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
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
                    // Header
                    VStack(spacing: 8) {
                        Text(isSignUp
                             ? LocalizedStringKey("auth.create_account")
                             : LocalizedStringKey("auth.sign_in"))
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(isSignUp
                             ? LocalizedStringKey("auth.create_subtitle")
                             : LocalizedStringKey("auth.welcome_back"))
                            .font(.body)
                            .foregroundColor(XpnseColorKey.white.color)
                            .multilineTextAlignment(.center)
                    }

                    // Form
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("auth.email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .xpnseStyledTextField()

                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("auth.password", text: $password)
                                .xpnseStyledTextField()

                            if isSignUp {
                                Text("auth.password_hint")
                                    .font(.caption)
                                    .foregroundColor(XpnseColorKey.white.color)
                                    .padding(.leading, 6)
                            }
                        }
                    }

                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            Task {
                                if isSignUp {
                                    await authManager.createAccount(email: email, password: password)
                                } else {
                                    await authManager.signInWithEmail(email, password: password)
                                }
                            }
                        }) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: XpnseColorKey.white.color))
                                        .scaleEffect(0.8)
                                }
                                Text(isSignUp
                                     ? LocalizedStringKey("auth.create_account")
                                     : LocalizedStringKey("auth.sign_in"))
                                    .fontWeight(.semibold)
                            }
                            .animation(.easeInOut, value: authManager.isLoading)
                        }
                        .buttonStyle(
                            XpnsePrimaryButtonStyle.defaultButton(
                                isDisabled: Binding(get: {
                                    email.isEmpty || password.isEmpty
                                }, set: {_ in }),
                                isLoading: Binding(get: {
                                    authManager.isLoading
                                }, set: {_ in })
                            )
                        )

                        if !isSignUp {
                            Button("auth.forgot_password") {
//                                authCoordinator.presentSheet(.forgotPassword)
                                authCoordinator.push(.forgotPassword)
                            }
                            .font(.caption)
                            .foregroundColor(XpnseColorKey.white.color)
                        }
                    }

                    // Toggle Sign In/Sign Up
                    Button(action: {
                        isSignUp.toggle()
                        authManager.clearError()
                    }) {
                        Text(isSignUp
                             ? LocalizedStringKey("auth.already_have_account")
                             : LocalizedStringKey("auth.no_account"))
                            .font(.caption)
                            .foregroundColor(XpnseColorKey.white.color)
                    }

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
//                        Text("Cancel")
//                            .padding(.all, 8)
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

struct EmailSignInView_Previews: PreviewProvider {
    static var authManager = MockFirebaseAuthManager()
    static var previews: some View {
        EmailSignInView(authManager: authManager)
    }
}
