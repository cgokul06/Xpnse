//
//  AppDeepLink.swift
//  Xpnse
//

import Combine
import Foundation

enum AppDeepLink: Equatable {
    case home
    case addTransaction(widgetFamily: String?)
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
            self = .addTransaction(widgetFamily: Self.widgetFamily(from: url))
        case "share-inbox":
            self = .shareInbox
        case "settings" where path == "app-lock":
            self = .settingsAppLock
        default:
            return nil
        }
    }

    private static func widgetFamily(from url: URL) -> String? {
        let family = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == WidgetReminderLink.familyQueryName }?
            .value
        switch family {
        case "systemSmall", "systemMedium":
            return family
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
    /// Set when an expense-reminder tap should open Add Expense without interrupting another flow.
    @Published private(set) var pendingRootAddExpense = false

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

        guard appCoordinator.currentRoute == .home else {
            if case .addTransaction(let widgetFamily) = link {
                AppAnalytics.logEvent(AppAnalytics.Event.widgetActionFailed, parameters: [
                    AppAnalytics.Param.widgetType: widgetFamily == nil ? "add" : "balance",
                    AppAnalytics.Param.failureReason: AppAnalytics.FailureReason.unavailable.rawValue
                ])
            }
            return
        }

        switch link {
        case .home:
            AppAnalytics.logEvent(AppAnalytics.Event.widgetDestinationOpened, parameters: [
                AppAnalytics.Param.widgetType: "balance",
                AppAnalytics.Param.destination: "home"
            ])
            homeCoordinator.popToRoot()
        case .addTransaction(let widgetFamily):
            var parameters = [
                AppAnalytics.Param.widgetType: widgetFamily == nil ? "add" : "balance",
                AppAnalytics.Param.destination: "add_transaction"
            ]
            if let widgetFamily {
                WidgetReminderAttribution.shared.noteOpened(family: widgetFamily)
                parameters[AppAnalytics.Param.widgetFamily] = widgetFamily
            }
            AppAnalytics.logEvent(AppAnalytics.Event.widgetDestinationOpened, parameters: parameters)
            homeCoordinator.popToRoot()
            homeCoordinator.push(.transactions(source: widgetFamily == nil ? .widgetAdd : .widgetBalance))
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

    func requestAddExpenseIfAtRoot() {
        pendingRootAddExpense = true
    }

    /// Opens Add Expense only when Home is visible and nothing else is already on the stack.
    func consumeRootAddExpenseIfNeeded(
        appCoordinator: AppCoordinator,
        homeCoordinator: NavigationCoordinator<HomeRoute>
    ) {
        guard pendingRootAddExpense else { return }
        guard appCoordinator.currentRoute == .home else { return }
        pendingRootAddExpense = false
        guard homeCoordinator.path.isEmpty,
              homeCoordinator.presentedSheet == nil,
              homeCoordinator.presentedFullScreenCover == nil else {
            return
        }
        homeCoordinator.push(.transactions(source: .notification))
    }
}

extension Notification.Name {
    static let focusAppLockSettings = Notification.Name("focusAppLockSettings")
}
