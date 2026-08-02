//
//  SceneDelegate.swift
//  Xpnse
//
//  Created by Gokul C on 17/11/25.
//

import SwiftUI
import WidgetKit
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
        let style = (scene as? UIWindowScene)?.traitCollection.userInterfaceStyle
            ?? SceneDelegate.window?.traitCollection.userInterfaceStyle
            ?? .unspecified
        WidgetAppearanceStore.sync(from: style)
        WidgetCenter.shared.reloadAllTimelines()
        Task { @MainActor in
            AppLockController.shared.evaluateLockStateOnActivation()
            UserSatisfactionEngine.shared.track(.appBecameActive)
            UserEngagementCoordinator.shared.attach(engine: .shared)
            UserEngagementCoordinator.shared.noteAppBecameActive()
            UserEngagementCoordinator.shared.reconcile()
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
        }
    }
}
