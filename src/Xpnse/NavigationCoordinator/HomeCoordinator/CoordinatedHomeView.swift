//
//  CoordinatedHomeView.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI
import Combine
import UIKit

struct CoordinatedHomeView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var billScannerService: BillScannerService = BillScannerService()
    @State private var engagement = UserEngagementCoordinator.shared
    @State private var appLock = AppLockController.shared
    @State private var showAppLockPromo = false
    /// Prevents re-showing after dismiss / sheet-driven onAppear races until next real foreground.
    @State private var didOfferPromoThisForeground = false
    @State private var pendingAppLockSettingsDeepLink = false
    @State private var wasInBackground = false

    var body: some View {
        NavigationStack(path: $homeCoordinator.path) {
            Home()
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .transactions:
                        AddTransactionView(billScannerService: billScannerService)
                    case .editTransaction(let transaction):
                        AddTransactionView(
                            billScannerService: billScannerService,
                            transaction: transaction
                        )
                    case .settings:
                        Settings()
                    case .billScanner:
                        if FeatureFlags.shared.receiptScanEnabled {
                            BillScannerView(billScannerService: billScannerService)
                        } else {
                            EmptyView()
                        }
                    case .insights:
                        if FeatureFlags.shared.insightsEnabled {
                            InsightsView()
                        } else {
                            EmptyView()
                        }
                    }
                }
        }
        .onAppear {
            engagement.attach(engine: .shared)
            engagement.markSettledPastLaunch()
            engagement.noteAppBecameActive()
            syncBusyWork(for: homeCoordinator.path)
            engagement.reconcile()
            evaluateAppLockPromo()
        }
        .onChange(of: homeCoordinator.path) { _, newPath in
            syncBusyWork(for: newPath)
            engagement.reconcile()
            // Never re-prompt while navigated away from home (e.g. Settings after Enable).
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                wasInBackground = true
            case .active:
                if wasInBackground {
                    wasInBackground = false
                    evaluateAppLockPromo()
                }
            default:
                break
            }
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            engagement.reconcile()
            engagement.checkPresentationGate()
            evaluateAppLockPromo()
        }
        // Edge-attached custom sheet: iOS 26 system `.medium` sheets are inset (Liquid Glass).
        .fullScreenCover(item: presentedEngagementBinding) { presentation in
            switch presentation {
            case .appReview(let opportunity):
                XpnseEdgeAttachedSheet {
                    FeedbackFlowView(opportunity: opportunity)
                }
            }
        }
        .fullScreenCover(isPresented: $showAppLockPromo, onDismiss: {
            // Ensure we never re-open from dismiss/onAppear races after a choice.
            didOfferPromoThisForeground = true
            guard pendingAppLockSettingsDeepLink else { return }
            pendingAppLockSettingsDeepLink = false
            AppDeepLinkRouter.shared.openSettingsAppLock(
                appCoordinator: appCoordinator,
                homeCoordinator: homeCoordinator
            )
        }) {
            XpnseEdgeAttachedSheet {
                AppLockPromoView(
                    onEnable: {
                        didOfferPromoThisForeground = true
                        pendingAppLockSettingsDeepLink = true
                        showAppLockPromo = false
                    },
                    onDismiss: {
                        didOfferPromoThisForeground = true
                        pendingAppLockSettingsDeepLink = false
                        showAppLockPromo = false
                    }
                )
            }
        }
    }

    private var presentedEngagementBinding: Binding<EngagementPresentation?> {
        Binding(
            get: { engagement.presentedEngagement },
            set: { newValue in
                if newValue == nil, engagement.presentedEngagement != nil {
                    engagement.dismissCurrentEngagement(reportToEngine: true)
                }
            }
        )
    }

    private func evaluateAppLockPromo() {
        guard !showAppLockPromo else { return }
        guard !appLock.isLocked else { return }
        // Only offer on the home root — not after Enable navigates into Settings.
        guard homeCoordinator.path.isEmpty else { return }
        guard !didOfferPromoThisForeground else { return }
        guard appLock.canOfferSoftPrompt else { return }
        didOfferPromoThisForeground = true
        showAppLockPromo = true
    }

    private func syncBusyWork(for path: [HomeRoute]) {
        engagement.endBusyWork(.addOrEditTransaction)
        engagement.endBusyWork(.billScanner)
        engagement.endBusyWork(.manageCategories)
        engagement.endBusyWork(.manageRecurring)
        engagement.endBusyWork(.settingsCriticalFlow)

        guard let top = path.last else { return }
        switch top {
        case .transactions, .editTransaction:
            engagement.beginBusyWork(.addOrEditTransaction)
        case .billScanner:
            engagement.beginBusyWork(.billScanner)
        case .settings:
            break
        case .insights:
            break
        }
    }
}
