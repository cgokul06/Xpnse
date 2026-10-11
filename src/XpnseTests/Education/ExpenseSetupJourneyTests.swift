//
//  ExpenseSetupJourneyTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class ExpenseSetupJourneyTests: XCTestCase {
    private let journey = ExpenseSetupJourney()
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func freshState() -> CampaignState {
        CampaignState.fresh(campaignID: ExpenseSetupJourney.campaignID)
    }

    private func incomeSetupState(_ status: CampaignStatus) -> CampaignState {
        var state = CampaignState.fresh(campaignID: IncomeSetupJourney.campaignID)
        state.status = status
        return state
    }

    private func allStates(
        including state: CampaignState,
        incomeSetup: CampaignState
    ) -> [CampaignState] {
        [state, incomeSetup]
    }

    private func eligibleContext(
        expenseCount: Int = 0,
        hasCriticalErrorThisSession: Bool = false
    ) -> CampaignContext {
        CampaignContext(
            expenseCount: expenseCount,
            hasCriticalErrorThisSession: hasCriticalErrorThisSession,
            evaluationDate: fixedDate
        )
    }

    func testEligibleAfterIncomeCompletedAndNoExpense() {
        let state = freshState()
        let context = eligibleContext()
        let states = allStates(including: state, incomeSetup: incomeSetupState(.completed))

        let decision = journey.evaluate(context: context, state: state, allStates: states)

        XCTAssertEqual(decision, .eligible)
        XCTAssertNotNil(journey.makeOpportunity(context: context, state: state, allStates: states))
    }

    func testEligibleAfterIncomeDeclinedAndNoExpense() {
        let state = freshState()
        let context = eligibleContext()
        let states = allStates(including: state, incomeSetup: incomeSetupState(.declined))

        XCTAssertEqual(
            journey.evaluate(context: context, state: state, allStates: states),
            .eligible
        )
    }

    func testNotEligibleWhenIncomeNotStarted() {
        let state = freshState()
        let context = eligibleContext()
        let states = allStates(including: state, incomeSetup: incomeSetupState(.notStarted))

        XCTAssertEqual(
            journey.evaluate(context: context, state: state, allStates: states),
            .notEligible(.prerequisiteNotCompleted(
                journeyID: IncomeSetupJourney.campaignID,
                requiredStatus: .completedOrDeclined,
                actualStatus: .notStarted
            ))
        )
        XCTAssertNil(journey.makeOpportunity(context: context, state: state, allStates: states))
    }

    func testNotEligibleWhenIncomeOnlyPresented() {
        let state = freshState()
        let context = eligibleContext()
        let states = allStates(including: state, incomeSetup: incomeSetupState(.presented))

        XCTAssertEqual(
            journey.evaluate(context: context, state: state, allStates: states),
            .notEligible(.prerequisiteNotCompleted(
                journeyID: IncomeSetupJourney.campaignID,
                requiredStatus: .completedOrDeclined,
                actualStatus: .presented
            ))
        )
    }

    func testNotEligibleWhenExpenseAlreadyExists() {
        let state = freshState()
        let context = eligibleContext(expenseCount: 1)
        let states = allStates(including: state, incomeSetup: incomeSetupState(.completed))

        XCTAssertEqual(
            journey.evaluate(context: context, state: state, allStates: states),
            .notEligible(.expenseExists)
        )
        XCTAssertNil(journey.makeOpportunity(context: context, state: state, allStates: states))
    }

    func testNotEligibleWhenCampaignCompleted() {
        var state = freshState()
        state.status = .completed
        let states = allStates(including: state, incomeSetup: incomeSetupState(.completed))

        XCTAssertEqual(
            journey.evaluate(context: eligibleContext(), state: state, allStates: states),
            .notEligible(.alreadyCompleted)
        )
    }

    func testNotEligibleWhenCampaignDeclined() {
        var state = freshState()
        state.status = .declined
        let states = allStates(including: state, incomeSetup: incomeSetupState(.completed))

        XCTAssertEqual(
            journey.evaluate(context: eligibleContext(), state: state, allStates: states),
            .notEligible(.alreadyDeclined)
        )
    }

    func testNotEligibleWhenCriticalSessionError() {
        let state = freshState()
        let context = eligibleContext(hasCriticalErrorThisSession: true)
        let states = allStates(including: state, incomeSetup: incomeSetupState(.completed))

        XCTAssertEqual(
            journey.evaluate(context: context, state: state, allStates: states),
            .notEligible(.custom("criticalSessionError"))
        )
    }

    func testDismissOutcomeIsDismissed() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)
        state = journey.applyOutcome(
            ExpenseSetupJourney.outcomeForDismiss(),
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext()
        )

        XCTAssertEqual(ExpenseSetupJourney.outcomeForDismiss(), .dismissed)
        XCTAssertEqual(state.status, .presented)
        XCTAssertEqual(state.dismissedCount, 1)
    }

    func testTransitionToCompletedAfterSuccessfulExpenseSave() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)
        state = journey.applyOutcome(
            ExpenseSetupJourney.outcomeForSuccessfulExpenseSave(),
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext(expenseCount: 1)
        )

        XCTAssertEqual(state.status, .completed)
        XCTAssertEqual(state.completedDate, fixedDate)
    }

    func testCompletionRejectedWithoutExpense() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)

        let result = journey.applyOutcome(
            .completed,
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext(expenseCount: 0)
        )

        XCTAssertEqual(result.status, .presented)
        XCTAssertNil(result.completedDate)
    }

    func testSecondaryDeclinesJourney() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)
        state = journey.applyOutcome(
            ExpenseSetupJourney.outcomeForSecondaryButton(),
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext()
        )

        XCTAssertEqual(ExpenseSetupJourney.outcomeForSecondaryButton(), .declined)
        XCTAssertEqual(state.status, .declined)
    }

    func testOpportunityGeneration() {
        let state = freshState()
        let context = eligibleContext()
        let states = allStates(including: state, incomeSetup: incomeSetupState(.completed))

        guard let opportunity = journey.makeOpportunity(context: context, state: state, allStates: states) else {
            return XCTFail("Expected opportunity")
        }

        XCTAssertEqual(opportunity.campaignID, ExpenseSetupJourney.campaignID)
        XCTAssertEqual(opportunity.priority, 5)
        XCTAssertEqual(opportunity.metadata?["journey"], ExpenseSetupJourney.campaignID)
        XCTAssertEqual(opportunity.sheetModel.title, "Track your first expense")
        XCTAssertEqual(
            opportunity.sheetModel.description,
            "Adding a spend helps SnapLedger understand where your money goes and personalize your dashboard."
        )
        XCTAssertEqual(opportunity.sheetModel.primaryButton.title, "Add Expense")
        XCTAssertEqual(opportunity.sheetModel.secondaryButton?.title, "Maybe Later")
        XCTAssertEqual(opportunity.primaryAction, .openAddTransaction(.expenseSetupDefault))

        guard case .openAddTransaction(let configuration) = opportunity.primaryAction else {
            return XCTFail("Expected openAddTransaction action")
        }
        XCTAssertEqual(configuration.transactionType, .expense)
        XCTAssertFalse(configuration.isRecurringEnabled)
    }

    func testDefaultRegistryPlacesExpenseBetweenIncomeAndCustomCategory() {
        let registry = CustomCategoryJourney.defaultRegistry

        XCTAssertEqual(
            registry.campaigns.map(\.identity.id),
            [
                IncomeSetupJourney.campaignID,
                RecurringReminderJourney.campaignID,
                ExpenseSetupJourney.campaignID,
                CustomCategoryJourney.campaignID
            ]
        )
    }

    func testEvaluationIsDeterministic() {
        let context = eligibleContext()
        let state = freshState()
        let states = allStates(including: state, incomeSetup: incomeSetupState(.completed))

        let first = journey.evaluate(context: context, state: state, allStates: states)
        let second = journey.evaluate(context: context, state: state, allStates: states)

        XCTAssertEqual(first, second)
    }

    func testDependsOnIncomeCompletedOrDeclined() {
        XCTAssertEqual(
            journey.prerequisites,
            [.completedOrDeclined(IncomeSetupJourney.campaignID)]
        )
    }
}
