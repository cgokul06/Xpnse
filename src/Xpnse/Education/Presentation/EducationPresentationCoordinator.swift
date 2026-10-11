//
//  EducationPresentationCoordinator.swift
//  Xpnse
//

import Foundation
import Observation

/// Bridge between `EducationEngine` and SwiftUI. Owns sheet timing, navigation, and outcomes.
@Observable
@MainActor
final class EducationPresentationCoordinator {
    static let shared = EducationPresentationCoordinator()

    /// Currently visible education sheet.
    private(set) var presentedOpportunity: EducationOpportunity?

    @ObservationIgnored private var engine: EducationPresentingEngine?
    @ObservationIgnored var notificationPermissionHandler: EducationNotificationPermissionHandling
    @ObservationIgnored private weak var navigator: EducationNavigating?
    @ObservationIgnored private var pendingOpportunity: EducationOpportunity?
    @ObservationIgnored private var suppressedCampaignIDs: Set<String> = []
    @ObservationIgnored private var hasSettledPastLaunch = false
    @ObservationIgnored private var isForegroundActive = false
    @ObservationIgnored private var isNavigationBusy = false
    @ObservationIgnored private var isOnHomeScreen = false
    @ObservationIgnored private var isCompetingOverlayPresented = false
    /// Host sets this from `CoordinatedHomeView` (defaults to false for tests and early init).
    @ObservationIgnored var isEngagementSheetPresented: () -> Bool = { false }
    /// When true, the next sheet dismiss should not record `.dismissed`.
    @ObservationIgnored var skipDismissOutcome = false

    init(
        engine: EducationPresentingEngine? = nil,
        notificationPermissionHandler: EducationNotificationPermissionHandling? = nil
    ) {
        self.engine = engine
        self.notificationPermissionHandler = notificationPermissionHandler ?? LiveEducationNotificationPermissionHandler()
    }

    func attach(
        engine: EducationPresentingEngine = EducationEngine.shared,
        navigator: EducationNavigating? = nil
    ) {
        self.engine = engine
        if let navigator {
            self.navigator = navigator
        }
        tryPresent()
    }

    func setNavigator(_ navigator: EducationNavigating?) {
        self.navigator = navigator
    }

    func markSettledPastLaunch() {
        hasSettledPastLaunch = true
        tryPresent()
    }

    func noteAppBecameActive() {
        isForegroundActive = true
        tryPresent()
    }

    func noteAppEnteredBackground() {
        isForegroundActive = false
    }

    func setNavigationBusy(_ busy: Bool) {
        let wasBusy = isNavigationBusy
        isNavigationBusy = busy
        if !busy {
            if wasBusy,
               let engine,
               engine.runtimeState.isWaitingForOutcome,
               let campaignID = engine.runtimeState.activeJourneyID {
                engine.applyOutcome(.actionFailed, campaignID: campaignID)
            }
            tryPresent()
        }
    }

    func setOnHomeScreen(_ onHome: Bool) {
        let becameHome = onHome && !isOnHomeScreen
        isOnHomeScreen = onHome
        if becameHome {
            engine?.track(.returnedToHome)
        }
        if onHome {
            tryPresent()
        }
    }

    func setCompetingOverlayPresented(_ presented: Bool) {
        isCompetingOverlayPresented = presented
        if !presented {
            tryPresent()
        }
    }

    func consumePublished(_ opportunity: EducationOpportunity?) {
        pendingOpportunity = opportunity
        tryPresent()
    }

    func tryPresent() {
        guard canPresent else { return }
        guard presentedOpportunity == nil else { return }
        guard engine?.isPresentationPending == true else { return }
        let candidate = pendingOpportunity ?? engine?.currentOpportunity
        guard let opportunity = candidate else { return }
        guard !suppressedCampaignIDs.contains(opportunity.campaignID) else { return }
        presentedOpportunity = opportunity
    }

    // MARK: - User actions

    func handlePrimary() {
        guard let opportunity = presentedOpportunity else { return }
        skipDismissOutcome = true
        engine?.acceptPrimaryAction(campaignID: opportunity.campaignID)
        presentedOpportunity = nil
        pendingOpportunity = nil
        perform(opportunity.primaryAction, campaignID: opportunity.campaignID)
    }

    func handleSecondary() {
        guard let opportunity = presentedOpportunity else { return }
        suppressedCampaignIDs.insert(opportunity.campaignID)
        skipDismissOutcome = true
        applyOutcome(Self.declinedOutcome(for: opportunity.campaignID), campaignID: opportunity.campaignID)
        presentedOpportunity = nil
        pendingOpportunity = nil
        tryPresent()
    }

    func handleInteractiveDismiss() {
        guard let opportunity = presentedOpportunity else { return }
        if skipDismissOutcome {
            skipDismissOutcome = false
            presentedOpportunity = nil
            return
        }
        suppressedCampaignIDs.insert(opportunity.campaignID)
        applyOutcome(Self.dismissedOutcome(for: opportunity.campaignID), campaignID: opportunity.campaignID)
        presentedOpportunity = nil
        pendingOpportunity = nil
        tryPresent()
    }

    func completeJourneysIfNeeded(for event: EducationEvent) {
        let completedID: String
        switch event {
        case .incomeConfigured, .recurringTransactionCreated:
            completedID = IncomeSetupJourney.campaignID
            applyOutcome(
                IncomeSetupJourney.outcomeForSuccessfulIncomeSave(),
                campaignID: completedID
            )
        case .expenseAdded:
            completedID = ExpenseSetupJourney.campaignID
            applyOutcome(
                ExpenseSetupJourney.outcomeForSuccessfulExpenseSave(),
                campaignID: completedID
            )
        case .categoryCreated:
            completedID = CustomCategoryJourney.campaignID
            applyOutcome(
                CustomCategoryJourney.outcomeForSuccessfulCustomCategoryCreation(),
                campaignID: completedID
            )
        default:
            return
        }

        suppressedCampaignIDs.insert(completedID)
        if presentedOpportunity?.campaignID == completedID {
            skipDismissOutcome = true
            presentedOpportunity = nil
        }
        tryPresent()
    }

    // MARK: - Internals

    private func applyOutcome(_ outcome: CampaignOutcome, campaignID: String) {
        engine?.applyOutcome(outcome, campaignID: campaignID)
    }

    private func perform(_ action: EducationJourneyAction, campaignID: String) {
        switch action {
        case .openAddTransaction(let configuration):
            navigator?.openAddTransaction(configuration.addTransactionPrefill)
        case .openManageCategories:
            navigator?.openManageCategories()
        case .requestNotificationPermission:
            Task { @MainActor [weak self] in
                guard let self else { return }
                let outcome = await self.notificationPermissionHandler.requestAuthorizationAndEnableReminder()
                self.applyOutcome(outcome, campaignID: campaignID)
                self.tryPresent()
            }
        }
    }

    private var canPresent: Bool {
        guard hasSettledPastLaunch else { return false }
        guard isForegroundActive else { return false }
        guard isOnHomeScreen else { return false }
        guard !isNavigationBusy else { return false }
        guard !isCompetingOverlayPresented else { return false }
        guard !isEngagementSheetPresented() else { return false }
        return true
    }

    private static func declinedOutcome(for campaignID: String) -> CampaignOutcome {
        switch campaignID {
        case RecurringReminderJourney.campaignID:
            return RecurringReminderJourney.outcomeForSecondaryButton()
        case ExpenseSetupJourney.campaignID:
            return ExpenseSetupJourney.outcomeForSecondaryButton()
        case CustomCategoryJourney.campaignID:
            return CustomCategoryJourney.outcomeForSecondaryButton()
        default:
            return IncomeSetupJourney.outcomeForSecondaryButton()
        }
    }

    private static func dismissedOutcome(for campaignID: String) -> CampaignOutcome {
        switch campaignID {
        case RecurringReminderJourney.campaignID:
            return RecurringReminderJourney.outcomeForDismiss()
        case ExpenseSetupJourney.campaignID:
            return ExpenseSetupJourney.outcomeForDismiss()
        case CustomCategoryJourney.campaignID:
            return CustomCategoryJourney.outcomeForDismiss()
        default:
            return IncomeSetupJourney.outcomeForDismiss()
        }
    }
}
