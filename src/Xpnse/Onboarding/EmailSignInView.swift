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
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(isSignUp ? "Create your expense tracker account" : "Welcome back to your expense tracker")
                            .font(.body)
                            .foregroundColor(XpnseColorKey.white.color)
                            .multilineTextAlignment(.center)
                    }

                    // Form
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Email", text: $email)
                            .textFieldStyle(XpnseTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)

                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("Password", text: $password)
                                .textFieldStyle(XpnseTextFieldStyle())

                            if isSignUp {
                                Text("Password must be at least 8 characters")
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
                                Text(isSignUp ? "Create Account" : "Sign In")
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
                            Button("Forgot Password?") {
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
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
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
            .alert("Error", isPresented: .constant(authManager.errorMessage != nil)) {
                Button("OK") {
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
