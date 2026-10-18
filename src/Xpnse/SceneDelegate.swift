//
//  SceneDelegate.swift
//  Xpnse
//
//  Created by Gokul C on 17/11/25.
//

import SwiftUI
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    static var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {
            SceneDelegate.window = windowScene.windows.first
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        Task { @MainActor in
            AppLockController.shared.showPrivacyCoverIfNeeded()
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        Task { @MainActor in
            AppLockController.shared.evaluateLockStateOnActivation()
            UserSatisfactionEngine.shared.track(.appBecameActive)
            UserEngagementCoordinator.shared.attach(engine: .shared)
            UserEngagementCoordinator.shared.noteAppBecameActive()
            UserEngagementCoordinator.shared.reconcile()
            if !EducationTracking.isRunningInTests {
                EducationPresentationCoordinator.shared.noteAppBecameActive()
                await EducationTracking.track(.appBecameActive)
                await ExpenseReminderScheduler.shared.handleDidBecomeActive()
                await ExpenseReminderScheduler.shared.requestProvisionalAuthorizationIfNeeded()
                WidgetTimelineReloader.reloadBalance()
                AnalyticsUserProperties.refresh()
            }
        }

        Task {
            await FirebaseTransactionManager.shared.processRecurringTransactionsAsync()
            await WidgetRefreshCoordinator.shared.refresh()
            await RemoteConfigService.shared.fetchAndActivateIfNeeded()
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        Task { @MainActor in
            AppLockController.shared.noteDidEnterBackground()
            UserSatisfactionEngine.shared.track(.appEnteredBackground)
            UserEngagementCoordinator.shared.noteAppEnteredBackground()
            WidgetReminderAttribution.shared.noteBackground()
            AppAnalytics.loggedUnavailableFeatures.removeAll()
            if !EducationTracking.isRunningInTests {
                EducationPresentationCoordinator.shared.noteAppEnteredBackground()
                await ExpenseReminderScheduler.shared.handleDidEnterBackground()
            }
        }
    }
}
