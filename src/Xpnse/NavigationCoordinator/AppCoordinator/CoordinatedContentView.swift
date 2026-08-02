//
//  CoordinatedContentView.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI
import WidgetKit

struct CoordinatedContentView: View {
    @StateObject private var appCoordinator = AppCoordinator()
    @StateObject private var homeCoordinator = NavigationCoordinator<HomeRoute>()
    @ObservedObject private var deepLinkRouter = AppDeepLinkRouter.shared
    @State private var appLock = AppLockController.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch appCoordinator.currentRoute {
            case .splash:
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0x03 / 255, green: 0x1B / 255, blue: 0x2E / 255),
                            Color(red: 0x0A / 255, green: 0x34 / 255, blue: 0x52 / 255)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 20) {
                        Image("SplashIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                        Text("SnapLedger")
                            .font(.custom("ArialRoundedMTBold", size: 32))
                            .foregroundStyle(.white)
                    }
                }
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
        .overlay {
            if appLock.isLocked {
                AppLockView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
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
        .onChange(of: colorScheme) { _, newScheme in
            syncWidgetAppearance(newScheme)
        }
        .onAppear {
            syncWidgetAppearance(colorScheme)
            appLock.evaluateLockStateOnActivation()
            deepLinkRouter.consumePendingLink(
                appCoordinator: appCoordinator,
                homeCoordinator: homeCoordinator
            )
        }
    }

    private func syncWidgetAppearance(_ scheme: ColorScheme) {
        WidgetAppearanceStore.sync(prefersDark: scheme == .dark)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    CoordinatedContentView()
}
