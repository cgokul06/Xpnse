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
                    Text("Reset Password")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.body)
                        .foregroundColor(XpnseColorKey.white.color)
                        .multilineTextAlignment(.center)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(XpnseTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

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
                            Text("Send Reset Link")
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
