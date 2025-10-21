//
//  AuthenticationFlowView.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI

// MARK: - Authentication Flow View
struct AuthenticationFlowView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var authCoordinator: NavigationCoordinator<AuthRoute>
    
    var body: some View {
        NavigationStack(path: $authCoordinator.path) {
            LoginView(authManager: appCoordinator.authManager)
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .main:
                        LoginView(authManager: appCoordinator.authManager)
                    case .emailSignIn:
                        EmailSignInView(authManager: appCoordinator.authManager)
                    case .forgotPassword:
                        ForgotPasswordView(authManager: appCoordinator.authManager)
                    }
                }
        }
//        .sheet(item: $authCoordinator.presentedSheet) { route in
//            switch route {
//            case .emailSignIn:
//                EmailSignInView(authManager: appCoordinator.authManager)
//            case .forgotPassword:
//                ForgotPasswordView(authManager: appCoordinator.authManager)
//            case .main:
//                EmptyView()
//            }
//        }
//        .fullScreenCover(item: $authCoordinator.presentedFullScreenCover) { route in
//            switch route {
//            case .emailSignIn:
//                EmailSignInView(authManager: appCoordinator.authManager)
//            case .forgotPassword:
//                ForgotPasswordView(authManager: appCoordinator.authManager)
//            case .main:
//                EmptyView()
//            }
//        }
    }
}
