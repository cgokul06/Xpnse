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
    @Published var currentRoute: AppRoute
    
    init() {
        self.currentRoute = CurrencyManager.shared.hasStoredSelection ? .home : .currencySetup
        FirebaseTransactionManager.shared.processRecurringTransactions()
    }
}


// MARK: - Login Navigation Methods

extension AppCoordinator {
    func navigateToAuthentication() {
        currentRoute = .home
    }

    func navigateToCurrencySetup() {
        currentRoute = .currencySetup
    }

    func navigateToHome() {
        currentRoute = .home
    }

    func signOut() {
        currentRoute = .home
    }
}
