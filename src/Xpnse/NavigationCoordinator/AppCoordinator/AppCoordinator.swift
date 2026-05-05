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
    @Published var currentRoute: AppRoute = .home
    
    init() {
        FirebaseTransactionManager.shared.processRecurringTransactions()
    }
}


// MARK: - Login Navigation Methods

extension AppCoordinator {
    func navigateToAuthentication() {
        currentRoute = .home
    }

    func navigateToHome() {
        currentRoute = .home
    }

    func signOut() {
        currentRoute = .home
    }
}
