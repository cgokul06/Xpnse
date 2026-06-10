//
//  CoordinatedContentView.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct CoordinatedContentView: View {
    @StateObject private var appCoordinator = AppCoordinator()
    @StateObject private var homeCoordinator = NavigationCoordinator<HomeRoute>()
    @ObservedObject private var deepLinkRouter = AppDeepLinkRouter.shared

    var body: some View {
        Group {
            switch appCoordinator.currentRoute {
            case .splash:
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.4, green: 0.2, blue: 0.8),
                        Color(red: 0.6, green: 0.3, blue: 0.9),
                        Color(red: 0.8, green: 0.4, blue: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
//            case .authentication:
//                CoordinatedHomeView()
            case .currencySetup:
                CurrencySelectionView()
            case .home:
                CoordinatedHomeView()
            }
        }
        .environmentObject(appCoordinator)
        .environmentObject(homeCoordinator)
        .animation(.easeInOut(duration: 0.3), value: appCoordinator.currentRoute)
        .onOpenURL { url in
            deepLinkRouter.handle(url)
            deepLinkRouter.consumePendingLink(
                appCoordinator: appCoordinator,
                homeCoordinator: homeCoordinator
            )
        }
        .onChange(of: appCoordinator.currentRoute) { _, newRoute in
            guard newRoute == .home else { return }
            deepLinkRouter.consumePendingLink(
                appCoordinator: appCoordinator,
                homeCoordinator: homeCoordinator
            )
        }
        .onAppear {
            deepLinkRouter.consumePendingLink(
                appCoordinator: appCoordinator,
                homeCoordinator: homeCoordinator
            )
        }
    }
}

#Preview {
    CoordinatedContentView()
}
