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
    private enum EngagementDismissMode {
        /// User cancelled / interactive dismiss — count as review dismiss.
        case reportDismiss
        /// Transitioning to the full-screen feedback form.
        case silent
        /// User chose Leave a Review — record App Store outcome after dismiss.
        case appStoreReview
    }

    private enum EngagementFollowUp {
        case sendFeedback
        case appStoreReview
    }

    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var billScannerService: BillScannerService = BillScannerService()
    @ObservedObject private var sharedTextImport = SharedTextImportController.shared
    @State private var engagement = UserEngagementCoordinator.shared
    @State private var appLock = AppLockController.shared
    @State private var showAppLockPromo = false
    /// Prevents re-showing after dismiss / sheet-driven onAppear races until next real foreground.
    @State private var didOfferPromoThisForeground = false
    @State private var pendingAppLockSettingsDeepLink = false
    @State private var wasInBackground = false
    @State private var engagementDismissMode: EngagementDismissMode = .reportDismiss
    @State private var pendingEngagementFollowUp: EngagementFollowUp?
    @State private var showSendFeedback = false

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
            if SharedTextInboxStore.hasContent {
                sharedTextImport.markPendingFromDeepLink()
            }
        }
        .task(id: sharedTextImport.pendingRequestID) {
            await sharedTextImport.processIfNeeded(
                billScannerService: billScannerService,
                homeCoordinator: homeCoordinator
            )
        }
        .overlay {
            if sharedTextImport.isAnalyzing {
                sharedTextAnalyzingOverlay
            }
        }
        .alert(
            L10n.tr("share.alert_title"),
            isPresented: Binding(
                get: { sharedTextImport.alertMessage != nil },
                set: { if !$0 { sharedTextImport.alertMessage = nil } }
            )
        ) {
            Button(L10n.tr("common.ok"), role: .cancel) {
                sharedTextImport.alertMessage = nil
            }
        } message: {
            Text(sharedTextImport.alertMessage ?? "")
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
        .fullScreenCover(item: presentedEngagementBinding, onDismiss: {
            runPendingEngagementFollowUp()
        }) { presentation in
            switch presentation {
            case .appReview(let opportunity):
                XpnseEdgeAttachedSheet {
                    FeedbackFlowView(
                        opportunity: opportunity,
                        onRequestSendFeedback: {
                            engagementDismissMode = .silent
                            pendingEngagementFollowUp = .sendFeedback
                        },
                        onRequestAppStoreReview: {
                            engagementDismissMode = .appStoreReview
                            pendingEngagementFollowUp = .appStoreReview
                        }
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $showSendFeedback) {
            NavigationStack {
                SendFeedbackView(
                    marksReviewOutcome: true,
                    showsCloseButton: true
                )
            }
        }
        .fullScreenCover(isPresented: $showAppLockPromo, onDismiss: {
            // Ensure we never re-open from dismiss/onAppear races after a choice.
            didOfferPromoThisForeground = true
            guard pendingAppLockSettingsDeepLink else { return }
            pendingAppLockSettingsDeepLink = false
            // Let the sheet finish dismissing before pushing Settings.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                AppDeepLinkRouter.shared.openSettingsAppLock(
                    appCoordinator: appCoordinator,
                    homeCoordinator: homeCoordinator
                )
            }
        }) {
            XpnseEdgeAttachedSheet {
                AppLockPromoView(
                    onEnable: {
                        didOfferPromoThisForeground = true
                        pendingAppLockSettingsDeepLink = true
                    },
                    onDismiss: {
                        didOfferPromoThisForeground = true
                        pendingAppLockSettingsDeepLink = false
                    }
                )
            }
        }
    }

    private var presentedEngagementBinding: Binding<EngagementPresentation?> {
        Binding(
            get: { engagement.presentedEngagement },
            set: { newValue in
                guard newValue == nil, engagement.presentedEngagement != nil else { return }
                switch engagementDismissMode {
                case .reportDismiss:
                    engagement.dismissCurrentEngagement(reportToEngine: true)
                case .silent:
                    engagement.clearPresentedWithoutReporting()
                case .appStoreReview:
                    engagement.reportAppStoreReviewOpened()
                }
                engagementDismissMode = .reportDismiss
            }
        )
    }

    private func runPendingEngagementFollowUp() {
        guard let followUp = pendingEngagementFollowUp else { return }
        pendingEngagementFollowUp = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            switch followUp {
            case .sendFeedback:
                showSendFeedback = true
            case .appStoreReview:
                AppStoreReviewRequester.requestReview()
            }
        }
    }

    private func evaluateAppLockPromo() {
        guard !showAppLockPromo else { return }
        guard !showSendFeedback else { return }
        guard engagement.presentedEngagement == nil else { return }
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

    private var sharedTextAnalyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("share.analyzing")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("share.analyzing"))
    }
}
