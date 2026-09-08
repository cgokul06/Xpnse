//
//  CustomCategoryJourneyTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class CustomCategoryJourneyTests: XCTestCase {
    private let journey = CustomCategoryJourney()
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func freshState() -> CampaignState {
        CampaignState.fresh(campaignID: CustomCategoryJourney.campaignID)
    }

    private func completedIncomeSetupState() -> CampaignState {
        var state = CampaignState.fresh(campaignID: IncomeSetupJourney.campaignID)
        state.status = .completed
        return state
    }

    private func allStates(
        including state: CampaignState,
        incomeSetup: CampaignState? = nil
    ) -> [CampaignState] {
        [state, incomeSetup ?? completedIncomeSetupState()]
    }

    private func eligibleContext(
        transactionCount: Int = CustomCategoryJourney.minimumTransactionCount,
        customCategoryCount: Int = 0,
        hasCriticalErrorThisSession: Bool = false
    ) -> CampaignContext {
        CampaignContext(
            transactionCount: transactionCount,
            customCategoryCount: customCategoryCount,
            hasCriticalErrorThisSession: hasCriticalErrorThisSession,
            evaluationDate: fixedDate
        )
    }

    private func validCompletionContext() -> CompletionValidationContext {
        CompletionValidationContext(customCategoryCount: 1)
    }

    func testEligibleWhenAllConditionsMet() {
        let state = freshState()
        let context = eligibleContext()
        let states = allStates(including: state)

        let decision = journey.evaluate(context: context, state: state, allStates: states)

        XCTAssertEqual(decision, .eligible)
        XCTAssertNotNil(journey.makeOpportunity(context: context, state: state, allStates: states))
    }

    func testNotEligibleWhenTooFewTransactions() {
        let context = eligibleContext(transactionCount: CustomCategoryJourney.minimumTransactionCount - 1)
        let state = freshState()
        let states = allStates(including: state)
        let decision = journey.evaluate(context: context, state: state, allStates: states)

        XCTAssertEqual(decision, .notEligible(.tooFewTransactions))
        XCTAssertNil(journey.makeOpportunity(context: context, state: state, allStates: states))
    }

    func testNotEligibleWhenCustomCategoryExists() {
        let context = eligibleContext(customCategoryCount: 1)
        let state = freshState()
        let states = allStates(including: state)
        let decision = journey.evaluate(context: context, state: state, allStates: states)

        XCTAssertEqual(decision, .notEligible(.customCategoryExists))
        XCTAssertNil(journey.makeOpportunity(context: context, state: state, allStates: states))
    }

    func testNotEligibleWhenIncomeSetupPrerequisiteMissing() {
        let context = eligibleContext()
        let state = freshState()
        let decision = journey.evaluate(context: context, state: state, allStates: [state])

        XCTAssertEqual(decision, .notEligible(.missingPrerequisite(journeyID: IncomeSetupJourney.campaignID)))
        XCTAssertNil(journey.makeOpportunity(context: context, state: state, allStates: [state]))
    }

    func testNotEligibleWhenIncomeSetupPrerequisiteNotCompleted() {
        let context = eligibleContext()
        let state = freshState()
        var incomeState = CampaignState.fresh(campaignID: IncomeSetupJourney.campaignID)
        incomeState.status = .presented
        let states = allStates(including: state, incomeSetup: incomeState)

        let decision = journey.evaluate(context: context, state: state, allStates: states)

        XCTAssertEqual(
            decision,
            .notEligible(
                .prerequisiteNotCompleted(
                    journeyID: IncomeSetupJourney.campaignID,
                    requiredStatus: .completed,
                    actualStatus: .presented
                )
            )
        )
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

    func testDismissedCampaignRemainsEligible() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)
        state = journey.applyOutcome(.dismissed, to: state, at: fixedDate, validationContext: CompletionValidationContext())
        let states = allStates(including: state)

        XCTAssertEqual(state.status, .presented)
        XCTAssertEqual(state.dismissedCount, 1)
        XCTAssertEqual(journey.evaluate(context: eligibleContext(), state: state, allStates: states), .eligible)
    }

    func testTransitionToCompletedAfterCustomCategoryCreation() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)
        state = journey.applyOutcome(
            CustomCategoryJourney.outcomeForSuccessfulCustomCategoryCreation(),
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

    func testSecondaryButtonOutcomeIsDeclined() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)
        state = journey.applyOutcome(
            CustomCategoryJourney.outcomeForSecondaryButton(),
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

        XCTAssertEqual(opportunity.campaignID, CustomCategoryJourney.campaignID)
        XCTAssertEqual(opportunity.priority, 10)
        XCTAssertEqual(opportunity.metadata?["journey"], CustomCategoryJourney.campaignID)
        XCTAssertEqual(opportunity.sheetModel.title, "Organize your spending your way")
        XCTAssertEqual(
            opportunity.sheetModel.description,
            "Create your own categories to match how you manage your finances. Whether it's Kids, Travel, Pets or Investments, SnapLedger adapts to you."
        )
        XCTAssertEqual(opportunity.sheetModel.primaryButton.title, "Create Category")
        XCTAssertEqual(opportunity.sheetModel.secondaryButton?.title, "Maybe Later")

        guard case .openAddTransaction(let configuration) = opportunity.primaryAction else {
            return XCTFail("Expected openAddTransaction action")
        }
        XCTAssertEqual(configuration, .customCategoryDiscovery)
        XCTAssertEqual(configuration.transactionType, .expense)
        XCTAssertFalse(configuration.isRecurringEnabled)
        XCTAssertTrue(configuration.focusCategoryPicker)
        XCTAssertTrue(configuration.enableAddCategoryShortcut)
    }

    func testCompletionRejectedWithoutValidContext() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)

        let result = journey.applyOutcome(
            .completed,
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext(customCategoryCount: 0)
        )

        XCTAssertEqual(result.status, .presented)
        XCTAssertNil(result.completedDate)
    }

    func testDefaultRegistrySortsIncomeSetupBeforeCustomCategory() {
        let recurringPlaceholder = MockEducationCampaign(id: "recurring_txn", priority: 20)
        let registry = EducationCampaignRegistry(campaigns: [
            recurringPlaceholder,
            CustomCategoryJourney(),
            IncomeSetupJourney()
        ])

        XCTAssertEqual(
            registry.campaigns.map(\.identity.id),
            [IncomeSetupJourney.campaignID, CustomCategoryJourney.campaignID, "recurring_txn"]
        )
    }

    func testEvaluationIsDeterministic() {
        let context = eligibleContext()
        let state = freshState()
        let states = allStates(including: state)

        let first = journey.evaluate(context: context, state: state, allStates: states)
        let second = journey.evaluate(context: context, state: state, allStates: states)

        XCTAssertEqual(first, second)
    }

    func testDeclaresIncomeSetupPrerequisite() {
        XCTAssertEqual(
            journey.prerequisites,
            [JourneyPrerequisite.completed(IncomeSetupJourney.campaignID)]
        )
    }
}
