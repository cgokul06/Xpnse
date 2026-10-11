//
//  EducationPresentationCoordinatorTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

@MainActor
final class EducationPresentationCoordinatorTests: XCTestCase {
    private static var retainedCoordinators: [EducationPresentationCoordinator] = []
    private static var retainedEngines: [FakeEducationEngine] = []
    private static var retainedNavigators: [RecordingEducationNavigator] = []

    func testPresentsIncomeOpportunityWhenEligible() {
        let (coordinator, engine, navigator) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        XCTAssertEqual(coordinator.presentedOpportunity?.campaignID, IncomeSetupJourney.campaignID)
        XCTAssertTrue(navigator.prefills.isEmpty)
    }

    func testPrimaryNavigatesWithoutCompletingOrDeclining() {
        let (coordinator, engine, navigator) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        coordinator.handlePrimary()

        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)
        XCTAssertEqual(engine.runtimeState, .waitingForOutcome(journeyID: IncomeSetupJourney.campaignID))
        XCTAssertEqual(engine.acceptedPrimaryCampaignIDs, [IncomeSetupJourney.campaignID])
        XCTAssertEqual(navigator.prefills.count, 1)
        XCTAssertEqual(navigator.prefills.first?.transactionType, .income)
        XCTAssertEqual(navigator.prefills.first?.isRecurring, true)
        XCTAssertTrue(engine.appliedOutcomes.isEmpty)
        XCTAssertEqual(navigator.openManageCategoriesCount, 0)
    }

    func testCustomCategoryPrimaryOpensManageCategories() {
        let (coordinator, engine, navigator) = makeReadyCoordinator()
        engine.currentOpportunity = customCategoryOpportunity()
        coordinator.tryPresent()

        coordinator.handlePrimary()

        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertEqual(engine.acceptedPrimaryCampaignIDs, [CustomCategoryJourney.campaignID])
        XCTAssertEqual(engine.runtimeState, .waitingForOutcome(journeyID: CustomCategoryJourney.campaignID))
        XCTAssertEqual(navigator.openManageCategoriesCount, 1)
        XCTAssertTrue(navigator.prefills.isEmpty)
        XCTAssertTrue(engine.appliedOutcomes.isEmpty)
    }

    func testPrimaryDoesNotRePresentWhileWaitingForOutcome() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()
        coordinator.handlePrimary()

        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertTrue(engine.appliedOutcomes.isEmpty)
        XCTAssertEqual(engine.runtimeState, .waitingForOutcome(journeyID: IncomeSetupJourney.campaignID))
    }

    func testLeavingAddTransactionSendsActionFailed() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()
        coordinator.handlePrimary()

        coordinator.setNavigationBusy(true)
        coordinator.setNavigationBusy(false)

        XCTAssertEqual(engine.appliedOutcomes.last?.0, .actionFailed)
        XCTAssertEqual(engine.appliedOutcomes.last?.1, IncomeSetupJourney.campaignID)
        XCTAssertEqual(engine.runtimeState, .idle)
    }

    func testLeavingManageCategoriesSendsActionFailed() {
        let (coordinator, engine, navigator) = makeReadyCoordinator()
        engine.currentOpportunity = customCategoryOpportunity()
        coordinator.tryPresent()
        coordinator.handlePrimary()

        coordinator.setNavigationBusy(true)
        coordinator.setNavigationBusy(false)

        XCTAssertEqual(navigator.openManageCategoriesCount, 1)
        XCTAssertEqual(engine.appliedOutcomes.last?.0, .actionFailed)
        XCTAssertEqual(engine.appliedOutcomes.last?.1, CustomCategoryJourney.campaignID)
        XCTAssertEqual(engine.runtimeState, .idle)
    }

    func testPrimaryThenIncomeSaveCompletesJourney() {
        let (coordinator, engine, navigator) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()
        coordinator.handlePrimary()
        coordinator.completeJourneysIfNeeded(for: .incomeConfigured)

        XCTAssertEqual(navigator.prefills.count, 1)
        XCTAssertEqual(engine.appliedOutcomes.map(\.0), [.completed])
        XCTAssertEqual(engine.appliedOutcomes.last?.1, IncomeSetupJourney.campaignID)
        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertNil(engine.currentOpportunity)
    }

    func testActionFailedThenLaterIncomeSaveStillCompletes() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()
        coordinator.handlePrimary()
        coordinator.setNavigationBusy(true)
        coordinator.setNavigationBusy(false)
        coordinator.completeJourneysIfNeeded(for: .incomeConfigured)

        XCTAssertEqual(engine.appliedOutcomes.map(\.0), [.actionFailed, .completed])
        XCTAssertEqual(engine.appliedOutcomes.last?.1, IncomeSetupJourney.campaignID)
    }

    func testSecondaryDeclinesJourney() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        coordinator.handleSecondary()

        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertEqual(engine.appliedOutcomes.last?.0, .declined)
        XCTAssertEqual(engine.appliedOutcomes.last?.1, IncomeSetupJourney.campaignID)
    }

    func testInteractiveDismissDeclinesIncomeSetup() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        coordinator.handleInteractiveDismiss()

        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertEqual(engine.appliedOutcomes.last?.0, .declined)
        XCTAssertEqual(engine.appliedOutcomes.last?.1, IncomeSetupJourney.campaignID)
    }

    func testInteractiveDismissDoesNotDeclineCustomCategory() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = customCategoryOpportunity()
        coordinator.tryPresent()

        coordinator.handleInteractiveDismiss()

        XCTAssertEqual(engine.appliedOutcomes.last?.0, .dismissed)
        XCTAssertEqual(engine.appliedOutcomes.last?.1, CustomCategoryJourney.campaignID)
    }

    func testDoesNotPresentWhenCompetingOverlayIsShown() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        coordinator.setCompetingOverlayPresented(true)
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        XCTAssertNil(coordinator.presentedOpportunity)
    }

    func testDoesNotPresentWhenNavigationIsBusy() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        coordinator.setNavigationBusy(true)
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        XCTAssertNil(coordinator.presentedOpportunity)
    }

    func testDoesNotPresentWhenNotOnHomeScreen() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        coordinator.setOnHomeScreen(false)
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        XCTAssertNil(coordinator.presentedOpportunity)
    }

    func testPresentsWhenReturningToHomeScreen() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        coordinator.setOnHomeScreen(false)
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()
        XCTAssertNil(coordinator.presentedOpportunity)

        coordinator.setOnHomeScreen(true)
        XCTAssertEqual(coordinator.presentedOpportunity?.campaignID, IncomeSetupJourney.campaignID)
    }

    func testDoesNotRePresentSameCampaignThisSessionAfterDismiss() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()
        coordinator.handleInteractiveDismiss()

        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        XCTAssertNil(coordinator.presentedOpportunity)
    }

    func testExpensePrimaryOpensAddExpense() {
        let (coordinator, engine, navigator) = makeReadyCoordinator()
        engine.currentOpportunity = expenseOpportunity()
        coordinator.tryPresent()

        coordinator.handlePrimary()

        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertEqual(engine.acceptedPrimaryCampaignIDs, [ExpenseSetupJourney.campaignID])
        XCTAssertEqual(engine.runtimeState, .waitingForOutcome(journeyID: ExpenseSetupJourney.campaignID))
        XCTAssertEqual(navigator.prefills.count, 1)
        XCTAssertEqual(navigator.prefills.first?.transactionType, .expense)
        XCTAssertEqual(navigator.prefills.first?.isRecurring, false)
        XCTAssertTrue(engine.appliedOutcomes.isEmpty)
    }

    func testExpenseAddedCompletesExpenseJourney() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = expenseOpportunity()
        coordinator.tryPresent()
        coordinator.handlePrimary()
        coordinator.completeJourneysIfNeeded(for: .expenseAdded)

        XCTAssertEqual(engine.appliedOutcomes.map(\.0), [.completed])
        XCTAssertEqual(engine.appliedOutcomes.last?.1, ExpenseSetupJourney.campaignID)
        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertNil(engine.currentOpportunity)
    }

    func testInteractiveDismissDoesNotDeclineExpenseSetup() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = expenseOpportunity()
        coordinator.tryPresent()

        coordinator.handleInteractiveDismiss()

        XCTAssertEqual(engine.appliedOutcomes.last?.0, .dismissed)
        XCTAssertEqual(engine.appliedOutcomes.last?.1, ExpenseSetupJourney.campaignID)
    }

    func testReminderPrimaryDismissesThenRequestsPermission() async {
        let handler = FakeNotificationPermissionHandler(outcome: .completed)
        let (coordinator, engine, _) = makeReadyCoordinator(permissionHandler: handler)
        engine.currentOpportunity = reminderOpportunity()
        coordinator.tryPresent()

        coordinator.handlePrimary()

        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertEqual(engine.acceptedPrimaryCampaignIDs, [RecurringReminderJourney.campaignID])
        XCTAssertEqual(engine.runtimeState, .waitingForOutcome(journeyID: RecurringReminderJourney.campaignID))
        for _ in 0..<20 where handler.callCount == 0 {
            await Task.yield()
        }
        XCTAssertEqual(handler.callCount, 1)
        XCTAssertEqual(engine.appliedOutcomes.last?.0, .completed)
        XCTAssertEqual(engine.appliedOutcomes.last?.1, RecurringReminderJourney.campaignID)
    }

    func testReminderPermissionDeniedContinuesWithoutEnabling() async {
        let handler = FakeNotificationPermissionHandler(outcome: .declined)
        let (coordinator, engine, _) = makeReadyCoordinator(permissionHandler: handler)
        engine.currentOpportunity = reminderOpportunity()
        coordinator.tryPresent()

        coordinator.handlePrimary()
        for _ in 0..<20 where handler.callCount == 0 {
            await Task.yield()
        }

        XCTAssertEqual(engine.appliedOutcomes.last?.0, .declined)
        XCTAssertNil(coordinator.presentedOpportunity)
    }

    func testReminderSecondaryDeclinesJourney() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = reminderOpportunity()
        coordinator.tryPresent()

        coordinator.handleSecondary()

        XCTAssertEqual(engine.appliedOutcomes.last?.0, .declined)
        XCTAssertEqual(engine.appliedOutcomes.last?.1, RecurringReminderJourney.campaignID)
    }

    func testReturningToHomeTracksReturnedToHome() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.trackedEvents.removeAll()

        coordinator.setOnHomeScreen(false)
        coordinator.setOnHomeScreen(true)

        XCTAssertEqual(engine.trackedEvents, [.returnedToHome])
    }

    func testSuccessfulIncomeSaveCompletesJourney() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()
        coordinator.completeJourneysIfNeeded(for: .incomeConfigured)

        XCTAssertEqual(engine.appliedOutcomes.last?.0, .completed)
        XCTAssertEqual(engine.appliedOutcomes.last?.1, IncomeSetupJourney.campaignID)
        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertNil(engine.currentOpportunity)
    }

    private func makeReadyCoordinator(
        permissionHandler: EducationNotificationPermissionHandling? = nil
    ) -> (
        EducationPresentationCoordinator,
        FakeEducationEngine,
        RecordingEducationNavigator
    ) {
        let engine = FakeEducationEngine()
        Self.retainedEngines.append(engine)
        let navigator = RecordingEducationNavigator()
        Self.retainedNavigators.append(navigator)
        let coordinator = EducationPresentationCoordinator(
            notificationPermissionHandler: permissionHandler ?? FakeNotificationPermissionHandler()
        )
        Self.retainedCoordinators.append(coordinator)
        coordinator.attach(engine: engine, navigator: navigator)
        coordinator.isEngagementSheetPresented = { false }
        coordinator.setOnHomeScreen(true)
        coordinator.markSettledPastLaunch()
        coordinator.noteAppBecameActive()
        return (coordinator, engine, navigator)
    }

    private func incomeOpportunity() -> EducationOpportunity {
        IncomeSetupJourney().buildOpportunity(
            context: CampaignContext(),
            state: CampaignState.fresh(campaignID: IncomeSetupJourney.campaignID)
        )
    }

    private func customCategoryOpportunity() -> EducationOpportunity {
        CustomCategoryJourney().buildOpportunity(
            context: CampaignContext(transactionCount: CustomCategoryJourney.minimumTransactionCount),
            state: CampaignState.fresh(campaignID: CustomCategoryJourney.campaignID)
        )
    }

    private func expenseOpportunity() -> EducationOpportunity {
        ExpenseSetupJourney().buildOpportunity(
            context: CampaignContext(),
            state: CampaignState.fresh(campaignID: ExpenseSetupJourney.campaignID)
        )
    }

    private func reminderOpportunity() -> EducationOpportunity {
        RecurringReminderJourney().buildOpportunity(
            context: CampaignContext(
                recurringTransactionCount: 1,
                notificationAuthorizationStatus: .notDetermined
            ),
            state: CampaignState.fresh(campaignID: RecurringReminderJourney.campaignID)
        )
    }
}

@MainActor
private final class RecordingEducationNavigator: EducationNavigating {
    var prefills: [AddTransactionPrefill] = []
    var openManageCategoriesCount = 0

    func openAddTransaction(_ prefill: AddTransactionPrefill) {
        prefills.append(prefill)
    }

    func openManageCategories() {
        openManageCategoriesCount += 1
    }
}

private final class FakeNotificationPermissionHandler: EducationNotificationPermissionHandling {
    var outcome: CampaignOutcome
    var callCount = 0

    init(outcome: CampaignOutcome = .completed) {
        self.outcome = outcome
    }

    func requestAuthorizationAndEnableReminder() async -> CampaignOutcome {
        callCount += 1
        return outcome
    }
}

final class FakeEducationEngine: EducationPresentingEngine {
    var runtimeState: EducationRuntimeState = .idle
    var currentOpportunity: EducationOpportunity? {
        didSet {
            if let currentOpportunity, runtimeState.isIdle {
                runtimeState = .presenting(journeyID: currentOpportunity.campaignID)
            }
        }
    }
    var appliedOutcomes: [(CampaignOutcome, String)] = []
    var acceptedPrimaryCampaignIDs: [String] = []
    var trackedEvents: [EducationEvent] = []

    var isPresentationPending: Bool {
        runtimeState.isPresentationPending
    }

    func track(_ event: EducationEvent) {
        trackedEvents.append(event)
    }

    func applyOutcome(_ outcome: CampaignOutcome, campaignID: String) {
        appliedOutcomes.append((outcome, campaignID))
        runtimeState = .idle
        currentOpportunity = nil
    }

    func acceptPrimaryAction(campaignID: String) {
        acceptedPrimaryCampaignIDs.append(campaignID)
        guard case .presenting(let activeID) = runtimeState, activeID == campaignID else {
            return
        }
        runtimeState = .waitingForOutcome(journeyID: campaignID)
    }
}
