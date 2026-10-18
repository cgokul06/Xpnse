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
        case reportDismiss
        case silent
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
    @State private var education = EducationPresentationCoordinator.shared
    @State private var educationNavigator: HomeEducationNavigator?
    @State private var appLock = AppLockController.shared
    @State private var showAppLockPromo = false
    @State private var didOfferPromoThisForeground = false
    @State private var pendingAppLockSettingsDeepLink = false
    @State private var wasInBackground = false
    @State private var engagementDismissMode: EngagementDismissMode = .reportDismiss
    @State private var pendingEngagementFollowUp: EngagementFollowUp?
    @State private var showSendFeedback = false

    private var educationEnabled: Bool {
        !EducationTracking.isRunningInTests
    }

    var body: some View {
        NavigationStack(path: $homeCoordinator.path) {
            Home()
                .ignoresSafeArea(.container, edges: .bottom)
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .transactions(let source):
                        AddTransactionView(billScannerService: billScannerService, source: source)
                    case .addTransaction(let prefill, let source):
                        AddTransactionView(
                            billScannerService: billScannerService,
                            prefill: prefill,
                            source: source
                        )
                    case .editTransaction(let transaction):
                        AddTransactionView(
                            billScannerService: billScannerService,
                            transaction: transaction,
                            source: .edit
                        )
                    case .settings:
                        Settings()
                    case .manageCategories:
                        ManageCategoriesView(openAddOnAppear: true)
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
        .onAppear(perform: handleOnAppear)
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
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                engagement.reconcile()
                engagement.checkPresentationGate()
                evaluateAppLockPromo()
            }
        }
        .modifier(EducationPresentationModifier(
            education: education,
            educationEnabled: educationEnabled,
            presentedEducationBinding: presentedEducationBinding
        ))
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
            if educationEnabled {
                education.setCompetingOverlayPresented(false)
            }
            didOfferPromoThisForeground = true
            guard pendingAppLockSettingsDeepLink else { return }
            pendingAppLockSettingsDeepLink = false
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

    private func handleOnAppear() {
        if educationEnabled {
            if educationNavigator == nil {
                let navigator = HomeEducationNavigator(coordinator: homeCoordinator)
                educationNavigator = navigator
                education.attach(navigator: navigator)
            }
            education.isEngagementSheetPresented = { engagement.presentedEngagement != nil }
            education.setOnHomeScreen(homeCoordinator.path.isEmpty)
            education.markSettledPastLaunch()
            education.noteAppBecameActive()
            education.tryPresent()
            engagement.isEducationSheetPresented = { education.presentedOpportunity != nil }
        } else {
            engagement.isEducationSheetPresented = { false }
        }
        engagement.attach(engine: .shared)
        engagement.markSettledPastLaunch()
        engagement.noteAppBecameActive()
        syncBusyWork(for: homeCoordinator.path)
        engagement.reconcile()
        evaluateAppLockPromo()
        if SharedTextInboxStore.hasContent || SharedImageInboxStore.hasContent {
            sharedTextImport.markPendingFromDeepLink()
        }
    }

    private var presentedEducationBinding: Binding<EducationOpportunity?> {
        Binding(
            get: { education.presentedOpportunity },
            set: { newValue in
                guard newValue == nil, education.presentedOpportunity != nil else { return }
                education.handleInteractiveDismiss()
            }
        )
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
        if educationEnabled {
            guard !education.isBlockingCompetingOverlays else { return }
        }
        guard !appLock.isLocked else { return }
        guard homeCoordinator.path.isEmpty else { return }
        guard !didOfferPromoThisForeground else { return }
        guard appLock.canOfferSoftPrompt else { return }
        didOfferPromoThisForeground = true
        if educationEnabled {
            education.setCompetingOverlayPresented(true)
        }
        showAppLockPromo = true
    }

    private func syncBusyWork(for path: [HomeRoute]) {
        engagement.endBusyWork(.addOrEditTransaction)
        engagement.endBusyWork(.billScanner)
        engagement.endBusyWork(.manageCategories)
        engagement.endBusyWork(.manageRecurring)
        engagement.endBusyWork(.settingsCriticalFlow)

        if educationEnabled {
            education.setOnHomeScreen(path.isEmpty)
            education.setNavigationBusy(!path.isEmpty)
        }

        guard let top = path.last else {
            return
        }
        switch top {
        case .transactions, .addTransaction, .editTransaction:
            engagement.beginBusyWork(.addOrEditTransaction)
        case .billScanner:
            engagement.beginBusyWork(.billScanner)
        case .manageCategories:
            engagement.beginBusyWork(.manageCategories)
        case .settings, .insights:
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

private struct EducationPresentationModifier: ViewModifier {
    let education: EducationPresentationCoordinator
    let educationEnabled: Bool
    let presentedEducationBinding: Binding<EducationOpportunity?>

    func body(content: Content) -> some View {
        if educationEnabled {
            content
                .task {
                    let stream = EducationEngine.shared.opportunityUpdates()
                    for await opportunity in stream {
                        education.consumePublished(opportunity)
                    }
                }
                .fullScreenCover(item: presentedEducationBinding) { opportunity in
                    XpnseEdgeAttachedSheet(sizing: .hug()) {
                        EducationBottomSheet(
                            model: opportunity.sheetModel,
                            onPrimary: { education.handlePrimary() },
                            onSecondary: { education.handleSecondary() }
                        )
                    }
                }
        } else {
            content
        }
    }
}

@MainActor
private final class HomeEducationNavigator: EducationNavigating {
    private let coordinator: NavigationCoordinator<HomeRoute>

    init(coordinator: NavigationCoordinator<HomeRoute>) {
        self.coordinator = coordinator
    }

    func openAddTransaction(_ prefill: AddTransactionPrefill) {
        let source: AppAnalytics.TxnSource = prefill.transactionType == .income ? .educationIncome : .educationExpense
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [coordinator] in
            coordinator.push(.addTransaction(prefill: prefill, source: source))
        }
    }

    func openManageCategories() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [coordinator] in
            withAnimation {
                coordinator.path.append(.settings)
                coordinator.path.append(.manageCategories)
            }
        }
    }
}
