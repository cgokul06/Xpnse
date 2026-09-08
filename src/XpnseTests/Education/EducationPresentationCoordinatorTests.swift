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

    func testPrimaryNavigatesWithoutCompleting() {
        let (coordinator, engine, navigator) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        coordinator.handlePrimary()

        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertNil(engine.currentOpportunity)
        XCTAssertEqual(navigator.prefills.count, 1)
        XCTAssertEqual(navigator.prefills.first?.transactionType, .income)
        XCTAssertEqual(navigator.prefills.first?.isRecurring, true)
        XCTAssertEqual(engine.appliedOutcomes.last?.0, .declined)
        XCTAssertEqual(engine.appliedOutcomes.last?.1, IncomeSetupJourney.campaignID)
    }

    func testPrimaryDoesNotRePresentAfterAbandonedSave() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()
        coordinator.handlePrimary()

        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertEqual(engine.appliedOutcomes.last?.0, .declined)
    }

    func testPrimaryThenIncomeSaveCompletesJourney() {
        let (coordinator, engine, navigator) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()
        coordinator.handlePrimary()
        coordinator.completeJourneysIfNeeded(for: .incomeConfigured)

        XCTAssertEqual(navigator.prefills.count, 1)
        XCTAssertEqual(engine.appliedOutcomes.map(\.0), [.declined, .completed])
        XCTAssertEqual(engine.appliedOutcomes.last?.1, IncomeSetupJourney.campaignID)
        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertNil(engine.currentOpportunity)
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

    func testInteractiveDismissIncrementsDismissedCount() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        coordinator.handleInteractiveDismiss()

        XCTAssertNil(coordinator.presentedOpportunity)
        XCTAssertEqual(engine.appliedOutcomes.last?.0, .dismissed)
        XCTAssertEqual(engine.appliedOutcomes.last?.1, IncomeSetupJourney.campaignID)
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

    func testDoesNotRePresentSameCampaignThisSessionAfterDismiss() {
        let (coordinator, engine, _) = makeReadyCoordinator()
        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()
        coordinator.handleInteractiveDismiss()

        engine.currentOpportunity = incomeOpportunity()
        coordinator.tryPresent()

        XCTAssertNil(coordinator.presentedOpportunity)
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

    private func makeReadyCoordinator() -> (
        EducationPresentationCoordinator,
        FakeEducationEngine,
        RecordingEducationNavigator
    ) {
        let engine = FakeEducationEngine()
        Self.retainedEngines.append(engine)
        let navigator = RecordingEducationNavigator()
        Self.retainedNavigators.append(navigator)
        let coordinator = EducationPresentationCoordinator()
        Self.retainedCoordinators.append(coordinator)
        coordinator.attach(engine: engine, navigator: navigator)
        coordinator.isEngagementSheetPresented = { false }
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
}

@MainActor
private final class RecordingEducationNavigator: EducationNavigating {
    var prefills: [AddTransactionPrefill] = []

    func openAddTransaction(_ prefill: AddTransactionPrefill) {
        prefills.append(prefill)
    }
}

final class FakeEducationEngine: EducationPresentingEngine {
    var currentOpportunity: EducationOpportunity?
    var appliedOutcomes: [(CampaignOutcome, String)] = []
    var evaluateCount = 0

    func applyOutcome(_ outcome: CampaignOutcome, campaignID: String) {
        appliedOutcomes.append((outcome, campaignID))
    }

    func clearCurrentOpportunity() {
        currentOpportunity = nil
    }

    func evaluateJourneys() {
        evaluateCount += 1
    }
}
