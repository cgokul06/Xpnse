//
//  AppDeepLink.swift
//  Xpnse
//

import Combine
import Foundation

enum AppDeepLink: Equatable {
    case home
    case addTransaction

    init?(url: URL) {
        guard url.scheme?.lowercased() == AppGroupConstants.urlScheme else { return nil }

        switch url.host?.lowercased() {
        case "home":
            self = .home
        case "add-transaction":
            self = .addTransaction
        default:
            return nil
        }
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
        }
    }
}
