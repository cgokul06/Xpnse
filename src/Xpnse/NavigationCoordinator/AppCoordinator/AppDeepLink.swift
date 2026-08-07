//
//  AppDeepLink.swift
//  Xpnse
//

import Combine
import Foundation

enum AppDeepLink: Equatable {
    case home
    case addTransaction
    case shareInbox
    case settingsAppLock

    init?(url: URL) {
        guard url.scheme?.lowercased() == AppGroupConstants.urlScheme else { return nil }

        let host = url.host?.lowercased() ?? ""
        let path = url.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()

        switch host {
        case "home":
            self = .home
        case "add-transaction":
            self = .addTransaction
        case "share-inbox":
            self = .shareInbox
        case "settings" where path == "app-lock":
            self = .settingsAppLock
        default:
            return nil
        }
    }

    /// Canonical in-app URL for opening Settings → App Lock.
    static var settingsAppLockURL: URL {
        URL(string: "\(AppGroupConstants.urlScheme)://settings/app-lock")!
    }
}

@MainActor
final class AppDeepLinkRouter: ObservableObject {
    static let shared = AppDeepLinkRouter()

    @Published private(set) var pendingLink: AppDeepLink?

    func handle(_ url: URL) {
        guard let link = AppDeepLink(url: url) else { return }
        pendingLink = link
    }

    func openSettingsAppLock(
        appCoordinator: AppCoordinator,
        homeCoordinator: NavigationCoordinator<HomeRoute>
    ) {
        pendingLink = .settingsAppLock
        consumePendingLink(appCoordinator: appCoordinator, homeCoordinator: homeCoordinator)
    }

    func consumePendingLink(
        appCoordinator: AppCoordinator,
        homeCoordinator: NavigationCoordinator<HomeRoute>
    ) {
        guard let link = pendingLink else { return }
        pendingLink = nil

        guard appCoordinator.currentRoute == .home else { return }

        switch link {
        case .home:
            homeCoordinator.popToRoot()
        case .addTransaction:
            homeCoordinator.popToRoot()
            homeCoordinator.push(.transactions)
        case .shareInbox:
            homeCoordinator.popToRoot()
            SharedTextImportController.shared.markPendingFromDeepLink()
        case .settingsAppLock:
            homeCoordinator.popToRoot()
            if homeCoordinator.path.last != .settings {
                homeCoordinator.push(.settings)
            }
            NotificationCenter.default.post(name: .focusAppLockSettings, object: nil)
        }
    }
}

extension Notification.Name {
    static let focusAppLockSettings = Notification.Name("focusAppLockSettings")
}
