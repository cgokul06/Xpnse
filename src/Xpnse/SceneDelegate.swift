//
//  SceneDelegate.swift
//  Xpnse
//
//  Created by Gokul C on 17/11/25.
//

import SwiftUI

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    static var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {}

    func sceneDidBecomeActive(_ scene: UIScene) {
        FirebaseTransactionManager.shared.processRecurringTransactions()
    }
}
