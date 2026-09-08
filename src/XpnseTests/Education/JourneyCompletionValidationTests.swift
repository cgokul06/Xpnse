//
//  JourneyCompletionValidationTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class JourneyCompletionValidationTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    private let incomeValidator = IncomeSetupCompletionValidator()
    private let categoryValidator = CustomCategoryCompletionValidator()
    private let trustingValidator = TrustingJourneyCompletionValidator()

    func testIncomeValidatorSucceedsWithConfiguredIncome() {
        let context = CompletionValidationContext(hasConfiguredIncome: true)

        XCTAssertEqual(incomeValidator.validate(context: context), .valid)
    }

    func testIncomeValidatorSucceedsWithRecurringIncomeOnly() {
        let context = CompletionValidationContext(hasRecurringIncome: true)

        XCTAssertEqual(incomeValidator.validate(context: context), .valid)
    }

    func testIncomeValidatorFailsWhenIncomeNotConfigured() {
        let context = CompletionValidationContext()

        XCTAssertEqual(
            incomeValidator.validate(context: context),
            .invalid(reason: .incomeNotConfigured)
        )
    }

    func testCategoryValidatorSucceedsWhenCustomCategoryExists() {
        let context = CompletionValidationContext(customCategoryCount: 1)

        XCTAssertEqual(categoryValidator.validate(context: context), .valid)
    }

    func testCategoryValidatorFailsWhenNoCustomCategory() {
        let context = CompletionValidationContext(customCategoryCount: 0)

        XCTAssertEqual(
            categoryValidator.validate(context: context),
            .invalid(reason: .noCustomCategory)
        )
    }

    func testTrustingValidatorAlwaysSucceeds() {
        let context = CompletionValidationContext()

        XCTAssertEqual(trustingValidator.validate(context: context), .valid)
    }

    func testIncomeJourneyCompletionAcceptedWithValidContext() {
        let journey = IncomeSetupJourney()
        var state = CampaignState.fresh(campaignID: IncomeSetupJourney.campaignID)
        state = CampaignStateTransition.markPresented(state, at: fixedDate)

        let validationContext = CompletionValidationContext(hasConfiguredIncome: true)
        let completed = journey.applyOutcome(
            .completed,
            to: state,
            at: fixedDate,
            validationContext: validationContext
        )

        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(completed.completedDate, fixedDate)
    }

    func testIncomeJourneyCompletionRejectedWithInvalidContext() {
        let journey = IncomeSetupJourney()
        var state = CampaignState.fresh(campaignID: IncomeSetupJourney.campaignID)
        state = CampaignStateTransition.markPresented(state, at: fixedDate)

        let completed = journey.applyOutcome(
            .completed,
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext()
        )

        XCTAssertEqual(completed, state)
        XCTAssertEqual(completed.status, .presented)
        XCTAssertNil(completed.completedDate)
    }

    func testCustomCategoryJourneyCompletionAcceptedWithValidContext() {
        let journey = CustomCategoryJourney()
        var state = CampaignState.fresh(campaignID: CustomCategoryJourney.campaignID)
        state = CampaignStateTransition.markPresented(state, at: fixedDate)

        let completed = journey.applyOutcome(
            .completed,
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext(customCategoryCount: 1)
        )

        XCTAssertEqual(completed.status, .completed)
    }

    func testCustomCategoryJourneyCompletionRejectedWithInvalidContext() {
        let journey = CustomCategoryJourney()
        var state = CampaignState.fresh(campaignID: CustomCategoryJourney.campaignID)
        state = CampaignStateTransition.markPresented(state, at: fixedDate)

        let completed = journey.applyOutcome(
            .completed,
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext(customCategoryCount: 0)
        )

        XCTAssertEqual(completed, state)
        XCTAssertEqual(completed.status, .presented)
    }

    func testMockCampaignTrustingValidatorAcceptsCompletion() {
        let campaign = MockEducationCampaign(decision: .eligible)
        var state = CampaignState.fresh(campaignID: "mock_campaign")
        state = CampaignStateTransition.markPresented(state, at: fixedDate)

        let completed = campaign.applyOutcome(
            .completed,
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext()
        )

        XCTAssertEqual(completed.status, .completed)
    }

    func testValidationIsDeterministic() {
        let context = CompletionValidationContext(hasConfiguredIncome: true)

        let first = incomeValidator.validate(context: context)
        let second = incomeValidator.validate(context: context)

        XCTAssertEqual(first, second)
    }

    func testContextExpansionDoesNotBreakExistingValidators() {
        let context = CompletionValidationContext(
            hasConfiguredIncome: true,
            hasRecurringIncome: false,
            customCategoryCount: 0,
            recurringExpenseCount: 3,
            isReminderEnabled: true,
            notificationAuthorizationStatus: .authorized,
            isWidgetInstalled: true,
            receiptScanCount: 10,
            hasGeneratedInsights: true
        )

        XCTAssertEqual(incomeValidator.validate(context: context), .valid)
        XCTAssertEqual(
            categoryValidator.validate(context: context),
            .invalid(reason: .noCustomCategory)
        )
    }

    func testCompletionValidationContextFromCampaignContext() {
        let campaignContext = CampaignContext(
            hasRecurringIncome: true,
            hasConfiguredIncome: false,
            customCategoryCount: 2,
            receiptScanCount: 5,
            notificationAuthorizationStatus: .denied,
            isWidgetInstalled: true
        )

        let validationContext = CompletionValidationContext.from(campaignContext: campaignContext)

        XCTAssertTrue(validationContext.hasRecurringIncome)
        XCTAssertFalse(validationContext.hasConfiguredIncome)
        XCTAssertEqual(validationContext.customCategoryCount, 2)
        XCTAssertEqual(validationContext.receiptScanCount, 5)
        XCTAssertEqual(validationContext.notificationAuthorizationStatus, .denied)
        XCTAssertTrue(validationContext.isWidgetInstalled)
        XCTAssertFalse(validationContext.isReminderEnabled)
        XCTAssertFalse(validationContext.hasGeneratedInsights)
    }
}
