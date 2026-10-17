//
//  IncomeSetupJourneyTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class IncomeSetupJourneyTests: XCTestCase {
    private let journey = IncomeSetupJourney()
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func freshState() -> CampaignState {
        CampaignState.fresh(campaignID: IncomeSetupJourney.campaignID)
    }

    private func allStates(including state: CampaignState) -> [CampaignState] {
        [state]
    }

    private func eligibleContext(
        transactionCount: Int = 0,
        hasRecurringIncome: Bool = false,
        hasConfiguredIncome: Bool = false,
        hasCriticalErrorThisSession: Bool = false
    ) -> CampaignContext {
        CampaignContext(
            transactionCount: transactionCount,
            hasRecurringIncome: hasRecurringIncome,
            hasConfiguredIncome: hasConfiguredIncome,
            hasCriticalErrorThisSession: hasCriticalErrorThisSession,
            evaluationDate: fixedDate
        )
    }

    private func validCompletionContext() -> CompletionValidationContext {
        CompletionValidationContext(hasConfiguredIncome: true)
    }

    func testEligibleWhenAllConditionsMet() {
        let state = freshState()
        let context = eligibleContext()
        let states = allStates(including: state)

        let decision = journey.evaluate(context: context, state: state, allStates: states)

        XCTAssertEqual(decision, .eligible)
        XCTAssertNotNil(journey.makeOpportunity(context: context, state: state, allStates: states))
    }

    func testNotEligibleWhenTransactionsAlreadyExist() {
        let context = eligibleContext(transactionCount: 1)
        let state = freshState()
        let states = allStates(including: state)
        let decision = journey.evaluate(context: context, state: state, allStates: states)

        XCTAssertEqual(decision, .notEligible(.transactionsExist))
        XCTAssertNil(journey.makeOpportunity(context: context, state: state, allStates: states))
    }

    func testNotEligibleWhenIncomeAlreadyConfigured() {
        let context = eligibleContext(hasConfiguredIncome: true)
        let state = freshState()
        let states = allStates(including: state)
        let decision = journey.evaluate(context: context, state: state, allStates: states)

        XCTAssertEqual(decision, .notEligible(.incomeExists))
        XCTAssertNil(journey.makeOpportunity(context: context, state: state, allStates: states))
    }

    func testNotEligibleWhenRecurringIncomeExists() {
        let context = eligibleContext(hasRecurringIncome: true)
        let state = freshState()
        let states = allStates(including: state)
        let decision = journey.evaluate(context: context, state: state, allStates: states)

        XCTAssertEqual(decision, .notEligible(.recurringIncomeExists))
        XCTAssertNil(journey.makeOpportunity(context: context, state: state, allStates: states))
    }

    func testNotEligibleWhenCampaignCompleted() {
        var state = freshState()
        state.status = .completed
        let states = allStates(including: state)

        let decision = journey.evaluate(context: eligibleContext(), state: state, allStates: states)

        XCTAssertEqual(decision, .notEligible(.alreadyCompleted))
        XCTAssertNil(journey.makeOpportunity(context: eligibleContext(), state: state, allStates: states))
    }

    func testNotEligibleWhenCampaignDeclined() {
        var state = freshState()
        state.status = .declined
        let states = allStates(including: state)

        let decision = journey.evaluate(context: eligibleContext(), state: state, allStates: states)

        XCTAssertEqual(decision, .notEligible(.alreadyDeclined))
        XCTAssertNil(journey.makeOpportunity(context: eligibleContext(), state: state, allStates: states))
    }

    func testDismissOutcomeIsDeclined() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)
        state = journey.applyOutcome(
            IncomeSetupJourney.outcomeForDismiss(),
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext()
        )
        let states = allStates(including: state)

        XCTAssertEqual(IncomeSetupJourney.outcomeForDismiss(), .declined)
        XCTAssertEqual(state.status, .declined)
        XCTAssertEqual(state.declinedDate, fixedDate)
        XCTAssertEqual(
            journey.evaluate(context: eligibleContext(), state: state, allStates: states),
            .notEligible(.alreadyDeclined)
        )
    }

    func testTransitionToCompletedAfterSuccessfulIncomeSave() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)
        state = journey.applyOutcome(
            IncomeSetupJourney.outcomeForSuccessfulIncomeSave(),
            to: state,
            at: fixedDate,
            validationContext: validCompletionContext()
        )
        let states = allStates(including: state)

        XCTAssertEqual(state.status, .completed)
        XCTAssertEqual(state.completedDate, fixedDate)
        XCTAssertEqual(
            journey.evaluate(context: eligibleContext(), state: state, allStates: states),
            .notEligible(.alreadyCompleted)
        )
    }

    func testPrimaryActionOutcomeIsDeclined() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)
        state = journey.applyOutcome(
            IncomeSetupJourney.outcomeForPrimaryAction(),
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext()
        )
        let states = allStates(including: state)

        XCTAssertEqual(state.status, .declined)
        XCTAssertEqual(
            journey.evaluate(context: eligibleContext(), state: state, allStates: states),
            .notEligible(.alreadyDeclined)
        )
    }

    func testPrimaryActionCanStillCompleteAfterIncomeSave() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)
        state = journey.applyOutcome(
            IncomeSetupJourney.outcomeForPrimaryAction(),
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext()
        )
        state = journey.applyOutcome(
            IncomeSetupJourney.outcomeForSuccessfulIncomeSave(),
            to: state,
            at: fixedDate,
            validationContext: validCompletionContext()
        )

        XCTAssertEqual(state.status, .completed)
        XCTAssertEqual(state.completedDate, fixedDate)
    }

    func testSecondaryButtonOutcomeIsDeclined() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)
        state = journey.applyOutcome(
            IncomeSetupJourney.outcomeForSecondaryButton(),
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext()
        )
        let states = allStates(including: state)

        XCTAssertEqual(state.status, .declined)
        XCTAssertEqual(
            journey.evaluate(context: eligibleContext(), state: state, allStates: states),
            .notEligible(.alreadyDeclined)
        )
    }

    func testOpportunityGeneration() {
        let state = freshState()
        let context = eligibleContext()
        let states = allStates(including: state)

        guard let opportunity = journey.makeOpportunity(context: context, state: state, allStates: states) else {
            return XCTFail("Expected opportunity")
        }

        XCTAssertEqual(opportunity.campaignID, IncomeSetupJourney.campaignID)
        XCTAssertEqual(opportunity.priority, 0)
        XCTAssertEqual(opportunity.metadata?["journey"], IncomeSetupJourney.campaignID)
        XCTAssertEqual(opportunity.sheetModel.title, L10n.tr("education.income.title"))
        XCTAssertEqual(
            opportunity.sheetModel.description,
            L10n.tr("education.income.description")
        )
        XCTAssertEqual(opportunity.sheetModel.primaryButton.title, L10n.tr("education.income.primary"))
        XCTAssertEqual(opportunity.sheetModel.secondaryButton?.title, L10n.tr("education.common.maybe_later"))

        guard case .openAddTransaction(let configuration) = opportunity.primaryAction else {
            return XCTFail("Expected openAddTransaction action")
        }
        XCTAssertEqual(configuration, .incomeSetupDefault)
        XCTAssertEqual(configuration.transactionType, .income)
        XCTAssertTrue(configuration.isRecurringEnabled)
    }

    func testCompletionRejectedWithoutValidContext() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)

        let result = journey.applyOutcome(
            .completed,
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext()
        )

        XCTAssertEqual(result.status, .presented)
        XCTAssertNil(result.completedDate)
    }

    func testDefaultRegistrySortsIncomeSetupFirst() {
        let lowerPriority = MockEducationCampaign(id: "other", priority: 10)
        let registry = EducationCampaignRegistry(campaigns: [lowerPriority, IncomeSetupJourney()])

        XCTAssertEqual(registry.campaigns.first?.identity.id, IncomeSetupJourney.campaignID)
    }

    func testEvaluationIsDeterministic() {
        let context = eligibleContext()
        let state = freshState()
        let states = allStates(including: state)

        let first = journey.evaluate(context: context, state: state, allStates: states)
        let second = journey.evaluate(context: context, state: state, allStates: states)

        XCTAssertEqual(first, second)
    }

    func testHasNoPrerequisites() {
        XCTAssertTrue(journey.prerequisites.isEmpty)
    }
}
