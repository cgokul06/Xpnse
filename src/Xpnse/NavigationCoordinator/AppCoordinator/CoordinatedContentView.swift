//
//  CoordinatedContentView.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct CoordinatedContentView: View {
    @StateObject private var appCoordinator = AppCoordinator()
    @StateObject private var authCoordinator = NavigationCoordinator<AuthRoute>()
    @StateObject private var homeCoordinator = NavigationCoordinator<HomeRoute>()
    
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
            case .authentication:
                AuthenticationFlowView()
            case .home:
                CoordinatedHomeView()
            }
        }
        .environmentObject(appCoordinator)
        .environmentObject(authCoordinator)
        .environmentObject(homeCoordinator)
        .animation(.easeInOut(duration: 0.3), value: appCoordinator.currentRoute)
    }
}

#Preview {
    CoordinatedContentView()
}
