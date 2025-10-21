//
//  LoginView.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct LoginView<AuthManager: AuthManagerProtocol>: View {
    @ObservedObject var authManager: AuthManager
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    @EnvironmentObject var authCoordinator: NavigationCoordinator<AuthRoute>

    init(authManager: AuthManager) {
        self._authManager = ObservedObject(wrappedValue: authManager)
    }

    var body: some View {
        ZStack {
            // Background Gradient
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
            
            VStack(spacing: 0) {
                // Top Section with Logo and App Info
                VStack(spacing: 24) {
                    Spacer()
                    
                    // App Logo
                    AppLogoView()
                    
                    // App Name and Tagline
                    VStack(spacing: 8) {
                        Text("Xpnse")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(XpnseColorKey.white.color)

                        Text("Smart Expense Tracking")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(XpnseColorKey.white.color.opacity(0.9))
                    }
                    
                    // Description
                    Text("Track expenses, analyze spending patterns, and take control of your finances with AI-powered insights.")
                        .font(.system(size: 16))
                        .foregroundColor(XpnseColorKey.white.color.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .lineLimit(3)
                    
                    Spacer()
                }
                
                // Bottom Section with Sign-In Options
                VStack(spacing: 16) {
                    // Sign-In Buttons
                    VStack(spacing: 12) {
                        // Google Sign-In
                        GoogleSignInButton(authManager: authManager)
                        
                        // Apple Sign-In
//                        AppleSignInButton()
                        
                        // Email Sign-In
                        EmailSignInButton {
                            authCoordinator.push(.emailSignIn)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Separator
                    HStack {
                        Rectangle()
                            .fill(XpnseColorKey.whiteWithAlphaThirty.color)
                            .frame(height: 1)
                        
                        Text("or")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(XpnseColorKey.white.color.opacity(0.7))
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .fill(XpnseColorKey.whiteWithAlphaThirty.color)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)
                    
                    // Guest Sign-In
                    GuestSignInButton(authManager: authManager)
                        .padding(.horizontal, 24)
                    
                    // Terms and Privacy
//                    VStack(spacing: 8) {
//                        HStack(spacing: 4) {
//                            Text("By continuing, you agree to our")
//                                .font(.system(size: 12))
//                                .foregroundColor(.white.opacity(0.7))
//                            
//                            Button("Terms of Service") {
//                                showingTerms = true
//                            }
//                            .font(.system(size: 12, weight: .medium))
//                            .foregroundColor(.white)
//                            .underline()
//                            
//                            Text("and")
//                                .font(.system(size: 12))
//                                .foregroundColor(.white.opacity(0.7))
//                            
//                            Button("Privacy Policy") {
//                                showingPrivacy = true
//                            }
//                            .font(.system(size: 12, weight: .medium))
//                            .foregroundColor(.white)
//                            .underline()
//                        }
//                        .multilineTextAlignment(.center)
//                    }
//                    .padding(.horizontal, 24)
//                    .padding(.bottom, 32)
                }
            }
        }
//        .sheet(isPresented: $showingEmailSignIn) {
//            EmailSignInView(authManager: authManager)
//        }
//        .sheet(isPresented: $showingTerms) {
//            TermsOfServiceView()
//        }
//        .sheet(isPresented: $showingPrivacy) {
//            PrivacyPolicyView()
//        }
        .alert("Error", isPresented: .constant(authManager.errorMessage != nil)) {
            Button("OK") {
                authManager.clearError()
            }
        } message: {
            Text(authManager.errorMessage ?? "")
        }
    }
}

// MARK: - App Logo View
struct AppLogoView: View {
    var body: some View {
        ZStack {
            // Background gradient for logo
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.1, blue: 0.6),
                    Color(red: 0.4, green: 0.2, blue: 0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Dollar sign and chart icon
            HStack(spacing: 4) {
                // Dollar sign
                Text("$")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(XpnseColorKey.white.color)

                // Arrow and chart
                VStack(spacing: 2) {
                    // Up arrow
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(XpnseColorKey.white.color)

                    // Mini bar chart
                    HStack(spacing: 1) {
                        Rectangle()
                            .fill(XpnseColorKey.white.color)
                            .frame(width: 2, height: 8)
                        Rectangle()
                            .fill(XpnseColorKey.white.color)
                            .frame(width: 2, height: 12)
                        Rectangle()
                            .fill(XpnseColorKey.white.color)
                            .frame(width: 2, height: 16)
                    }
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var authManager = MockFirebaseAuthManager()
    static var previews: some View {
        LoginView(authManager: authManager)
    }
}
