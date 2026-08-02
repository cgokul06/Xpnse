//
//  AppDelegate.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import UIKit
import Foundation
import FirebaseCore

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        AnonymousIdentity.bootstrap()
        RecurringReminderScheduler.shared.configureNotificationCenterDelegate()
        Task { @MainActor in
            UserSatisfactionEngine.shared.track(.appLaunched)
            UserEngagementCoordinator.shared.attach(engine: .shared)
            await CategoryStore.shared.load()
            await RemoteConfigService.shared.fetchAndActivateIfNeeded(force: true)
            await reconcileSatisfactionLifetimeCounts()
        }
        return true
    }

    @MainActor
    private func reconcileSatisfactionLifetimeCounts() async {
        guard let transactions = try? await SwiftDataTransactionRepository.shared.fetchAll() else {
            return
        }
        UserSatisfactionEngine.shared.reconcileLifetimeTransactionCount(transactions.count)
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = SceneDelegate.self
        return config
    }
}

