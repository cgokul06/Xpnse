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
    @ObservationIgnored private weak var navigator: EducationNavigating?
    @ObservationIgnored private var pendingOpportunity: EducationOpportunity?
    @ObservationIgnored private var suppressedCampaignIDs: Set<String> = []
    @ObservationIgnored private var hasSettledPastLaunch = false
    @ObservationIgnored private var isForegroundActive = false
    @ObservationIgnored private var isNavigationBusy = false
    @ObservationIgnored private var isCompetingOverlayPresented = false
    /// Host sets this from `CoordinatedHomeView` (defaults to false for tests and early init).
    @ObservationIgnored var isEngagementSheetPresented: () -> Bool = { false }
    /// When true, the next sheet dismiss should not record `.dismissed`.
    @ObservationIgnored var skipDismissOutcome = false

    init(engine: EducationPresentingEngine? = nil) {
        self.engine = engine
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
        isNavigationBusy = busy
        if !busy {
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
        let candidate = pendingOpportunity ?? engine?.currentOpportunity
        guard let opportunity = candidate else { return }
        guard !suppressedCampaignIDs.contains(opportunity.campaignID) else { return }
        presentedOpportunity = opportunity
    }

    // MARK: - User actions

    func handlePrimary() {
        guard let opportunity = presentedOpportunity else { return }
        suppressedCampaignIDs.insert(opportunity.campaignID)
        skipDismissOutcome = true
        if let outcome = Self.primaryOutcome(for: opportunity.campaignID) {
            applyOutcome(outcome, campaignID: opportunity.campaignID)
        }
        presentedOpportunity = nil
        engine?.clearCurrentOpportunity()
        pendingOpportunity = nil
        perform(opportunity.primaryAction)
    }

    func handleSecondary() {
        guard let opportunity = presentedOpportunity else { return }
        suppressedCampaignIDs.insert(opportunity.campaignID)
        skipDismissOutcome = true
        applyOutcome(Self.declinedOutcome(for: opportunity.campaignID), campaignID: opportunity.campaignID)
        presentedOpportunity = nil
        engine?.clearCurrentOpportunity()
        pendingOpportunity = nil
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
        engine?.clearCurrentOpportunity()
        pendingOpportunity = nil
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
        engine?.clearCurrentOpportunity()
        engine?.evaluateJourneys()
        tryPresent()
    }

    // MARK: - Internals

    private func applyOutcome(_ outcome: CampaignOutcome, campaignID: String) {
        engine?.applyOutcome(outcome, campaignID: campaignID)
    }

    private func perform(_ action: EducationJourneyAction) {
        switch action {
        case .openAddTransaction(let configuration):
            navigator?.openAddTransaction(configuration.addTransactionPrefill)
        }
    }

    private var canPresent: Bool {
        guard hasSettledPastLaunch else { return false }
        guard isForegroundActive else { return false }
        guard !isNavigationBusy else { return false }
        guard !isCompetingOverlayPresented else { return false }
        guard !isEngagementSheetPresented() else { return false }
        return true
    }

    private static func primaryOutcome(for campaignID: String) -> CampaignOutcome? {
        switch campaignID {
        case IncomeSetupJourney.campaignID:
            return IncomeSetupJourney.outcomeForPrimaryAction()
        default:
            return nil
        }
    }

    private static func declinedOutcome(for campaignID: String) -> CampaignOutcome {
        switch campaignID {
        case CustomCategoryJourney.campaignID:
            return CustomCategoryJourney.outcomeForSecondaryButton()
        default:
            return IncomeSetupJourney.outcomeForSecondaryButton()
        }
    }

    private static func dismissedOutcome(for campaignID: String) -> CampaignOutcome {
        switch campaignID {
        case CustomCategoryJourney.campaignID:
            return CustomCategoryJourney.outcomeForDismiss()
        default:
            return IncomeSetupJourney.outcomeForDismiss()
        }
    }
}
