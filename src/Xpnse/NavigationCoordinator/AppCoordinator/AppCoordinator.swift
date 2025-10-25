//
//  AppCoordinator.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI
import Combine

@MainActor
class AppCoordinator: ObservableObject {
    @Published var currentRoute: AppRoute = .splash
    @Published var authManager: FirebaseAuthManager

    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.authManager = FirebaseAuthManager()
        setupAuthListener()
    }
    
    private func setupAuthListener() {
        authManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                guard let isAuthenticated, let self else { return }
                if isAuthenticated {
                    FirebaseTransactionManager.setup(authManager: self.authManager)
                    self.navigateToHome()
                } else {
                    print("not auth")
                    self.navigateToAuthentication()
                }
            }
            .store(in: &cancellables)
    }
}


// MARK: - Login Navigation Methods

extension AppCoordinator {
    func navigateToAuthentication() {
        FirebaseTransactionManager.reset()
        currentRoute = .authentication
    }

    func navigateToHome() {
        currentRoute = .home
    }

    func signOut() {
        authManager.signOut()
    }
}
