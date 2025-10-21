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
    @Published var transactionManager: FirebaseTransactionManager?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.authManager = FirebaseAuthManager()
        setupAuthListener()
    }
    
    private func setupAuthListener() {
        authManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                guard let isAuthenticated else { return }
                if isAuthenticated {
                    self?.navigateToHome()
                } else {
                    print("not auth")
                    self?.navigateToAuthentication()
                }
            }
            .store(in: &cancellables)
    }
}


// MARK: - Login Navigation Methods

extension AppCoordinator {
    func navigateToAuthentication() {
        currentRoute = .authentication
        transactionManager = nil
    }

    func navigateToHome() {
        currentRoute = .home
        transactionManager = FirebaseTransactionManager(authManager: authManager)
    }

    func signOut() {
        authManager.signOut()
    }
}
