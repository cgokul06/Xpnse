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

    /// True while an education sheet is visible or waiting to present (including the Home delay).
    var isBlockingCompetingOverlays: Bool {
        presentedOpportunity != nil || engine?.isPresentationPending == true
    }

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
    /// Add Transaction continues the pending recurring save. `true` means Remind me should be on.
    @ObservationIgnored var hostFinishRecurringSave: ((Bool) async -> Void)?
    @ObservationIgnored var notificationStatusLoader: () async -> EducationNotificationAuthorizationStatus = {
        await EducationNotificationAuthorizationStatus.loadCurrent()
    }
    @ObservationIgnored private var homePresentationDelayTask: Task<Void, Never>?
    @ObservationIgnored private var isHomePresentationDelayElapsed = false
    @ObservationIgnored private let homePresentationDelay: TimeInterval

    init(
        engine: EducationPresentingEngine? = nil,
        notificationPermissionHandler: EducationNotificationPermissionHandling? = nil,
        homePresentationDelay: TimeInterval? = nil
    ) {
        self.engine = engine
        self.notificationPermissionHandler = notificationPermissionHandler ?? LiveEducationNotificationPermissionHandler()
        if let homePresentationDelay {
            self.homePresentationDelay = homePresentationDelay
        } else {
            self.homePresentationDelay = EducationTracking.isRunningInTests ? 0 : 1.5
        }
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
               let campaignID = engine.runtimeState.activeJourneyID,
               campaignID != RecurringReminderJourney.campaignID {
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
            scheduleHomePresentationDelay()
        } else if !onHome {
            cancelHomePresentationDelay()
        } else {
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
        guard presentedOpportunity == nil else { return }
        guard engine?.isPresentationPending == true else { return }
        let candidate = pendingOpportunity ?? engine?.currentOpportunity
        guard let opportunity = candidate else { return }
        guard canPresent(opportunity) else { return }
        guard !suppressedCampaignIDs.contains(opportunity.campaignID) else { return }
        skipDismissOutcome = false
        presentedOpportunity = opportunity
        EducationAnalytics.presented(campaignID: opportunity.campaignID, trigger: "home_visit")
    }

    /// Shows the reminder sheet on Add Transaction **before** the recurring item is saved.
    func beginReminderPromptOnAddTransaction() async -> Bool {
        guard canBeginHostedPrompt(RecurringReminderJourney.campaignID) else { return false }
        let status = await notificationStatusLoader()
        guard canBeginHostedPrompt(RecurringReminderJourney.campaignID), let engine else { return false }
        guard let opportunity = engine.beginHostedPresentation(
            campaignID: RecurringReminderJourney.campaignID,
            adjustingContext: { context in
                context.reminderEligibleRecurringCount += 1
                context.notificationAuthorizationStatus = status
            }
        ) else {
            return false
        }
        skipDismissOutcome = false
        pendingOpportunity = opportunity
        presentedOpportunity = opportunity
        EducationAnalytics.presented(campaignID: opportunity.campaignID, trigger: "recurring_save")
        return true
    }

    private func canBeginHostedPrompt(_ campaignID: String) -> Bool {
        presentedOpportunity == nil
            && hasSettledPastLaunch
            && isForegroundActive
            && !isCompetingOverlayPresented
            && !isEngagementSheetPresented()
            && !suppressedCampaignIDs.contains(campaignID)
    }

    // MARK: - User actions

    func handlePrimary() {
        guard let opportunity = presentedOpportunity else { return }
        EducationAnalytics.actionSelected(campaignID: opportunity.campaignID, action: opportunity.primaryAction)
        skipDismissOutcome = true
        engine?.acceptPrimaryAction(campaignID: opportunity.campaignID)
        presentedOpportunity = nil
        pendingOpportunity = nil
        perform(opportunity.primaryAction, campaignID: opportunity.campaignID)
    }

    func handleSecondary() {
        guard let opportunity = presentedOpportunity else { return }
        EducationAnalytics.dismissed(campaignID: opportunity.campaignID, method: "secondary_button")
        suppressedCampaignIDs.insert(opportunity.campaignID)
        skipDismissOutcome = true
        applyOutcome(Self.declinedOutcome(for: opportunity.campaignID), campaignID: opportunity.campaignID)
        presentedOpportunity = nil
        pendingOpportunity = nil
        finishHostRecurringSave(enableReminder: false, campaignID: opportunity.campaignID)
        tryPresent()
    }

    func handleInteractiveDismiss() {
        guard let opportunity = presentedOpportunity else { return }
        if skipDismissOutcome {
            skipDismissOutcome = false
            presentedOpportunity = nil
            return
        }
        EducationAnalytics.dismissed(campaignID: opportunity.campaignID, method: "swipe")
        suppressedCampaignIDs.insert(opportunity.campaignID)
        applyOutcome(Self.dismissedOutcome(for: opportunity.campaignID), campaignID: opportunity.campaignID)
        presentedOpportunity = nil
        pendingOpportunity = nil
        finishHostRecurringSave(enableReminder: false, campaignID: opportunity.campaignID)
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
                if outcome == .completed, self.hostFinishRecurringSave != nil {
                    // Completion is validated against saved data, so the reminder must be persisted first.
                    await self.finishHostRecurringSaveAsync(enableReminder: true, campaignID: campaignID)
                    self.applyOutcome(outcome, campaignID: campaignID)
                    if self.engine?.runtimeState.activeJourneyID == campaignID {
                        self.applyOutcome(.actionFailed, campaignID: campaignID)
                    }
                } else {
                    self.applyOutcome(outcome == .completed ? .actionFailed : outcome, campaignID: campaignID)
                    await self.finishHostRecurringSaveAsync(enableReminder: false, campaignID: campaignID)
                }
                self.tryPresent()
            }
        }
    }

    private func finishHostRecurringSave(enableReminder: Bool, campaignID: String) {
        guard campaignID == RecurringReminderJourney.campaignID else { return }
        Task { @MainActor [weak self] in
            await self?.finishHostRecurringSaveAsync(enableReminder: enableReminder, campaignID: campaignID)
        }
    }

    private func finishHostRecurringSaveAsync(enableReminder: Bool, campaignID: String) async {
        guard campaignID == RecurringReminderJourney.campaignID else { return }
        suppressedCampaignIDs.insert(campaignID)
        let host = hostFinishRecurringSave
        hostFinishRecurringSave = nil
        await host?(enableReminder)
    }

    private func canPresent(_ opportunity: EducationOpportunity) -> Bool {
        guard hasSettledPastLaunch else { return false }
        guard isForegroundActive else { return false }
        guard !isCompetingOverlayPresented else { return false }
        guard !isEngagementSheetPresented() else { return false }
        if opportunity.campaignID == RecurringReminderJourney.campaignID {
            return true
        }
        guard isOnHomeScreen else { return false }
        guard !isNavigationBusy else { return false }
        guard isHomePresentationDelayElapsed else { return false }
        return true
    }

    private func scheduleHomePresentationDelay() {
        cancelHomePresentationDelay()
        if homePresentationDelay <= 0 {
            isHomePresentationDelayElapsed = true
            tryPresent()
            return
        }
        let delay = homePresentationDelay
        homePresentationDelayTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.isHomePresentationDelayElapsed = true
            self.homePresentationDelayTask = nil
            self.tryPresent()
        }
    }

    private func cancelHomePresentationDelay() {
        homePresentationDelayTask?.cancel()
        homePresentationDelayTask = nil
        isHomePresentationDelayElapsed = false
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
