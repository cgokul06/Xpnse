//
//  RecurringReminderJourneyTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class RecurringReminderJourneyTests: XCTestCase {
    private let journey = RecurringReminderJourney()
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func freshState() -> CampaignState {
        CampaignState.fresh(campaignID: RecurringReminderJourney.campaignID)
    }

    private func eligibleContext(
        recurringTransactionCount: Int = 1,
        hasEnabledRecurringReminder: Bool = false,
        notificationAuthorizationStatus: EducationNotificationAuthorizationStatus = .notDetermined,
        hasCriticalErrorThisSession: Bool = false
    ) -> CampaignContext {
        CampaignContext(
            recurringTransactionCount: recurringTransactionCount,
            hasEnabledRecurringReminder: hasEnabledRecurringReminder,
            notificationAuthorizationStatus: notificationAuthorizationStatus,
            hasCriticalErrorThisSession: hasCriticalErrorThisSession,
            evaluationDate: fixedDate
        )
    }

    func testEligibleWhenFirstRecurringSavedWithoutNotifyAndPermissionUndetermined() {
        let state = freshState()
        let context = eligibleContext()

        XCTAssertEqual(journey.evaluate(context: context, state: state, allStates: [state]), .eligible)
        XCTAssertNotNil(journey.makeOpportunity(context: context, state: state, allStates: [state]))
    }

    func testNotEligibleWhenNoRecurringExists() {
        let context = eligibleContext(recurringTransactionCount: 0)

        XCTAssertEqual(
            journey.evaluate(context: context, state: freshState(), allStates: [freshState()]),
            .notEligible(.noRecurringTransaction)
        )
    }

    func testNotEligibleWhenNotifyAlreadyEnabled() {
        let context = eligibleContext(hasEnabledRecurringReminder: true)

        XCTAssertEqual(
            journey.evaluate(context: context, state: freshState(), allStates: [freshState()]),
            .notEligible(.reminderAlreadyEnabled)
        )
    }

    func testNotEligibleWhenNotificationAlreadyGranted() {
        for status: EducationNotificationAuthorizationStatus in [.authorized, .provisional, .ephemeral] {
            let context = eligibleContext(notificationAuthorizationStatus: status)
            XCTAssertEqual(
                journey.evaluate(context: context, state: freshState(), allStates: [freshState()]),
                .notEligible(.notificationAlreadyGranted),
                "status \(status)"
            )
        }
    }

    func testNotEligibleWhenNotificationDenied() {
        let context = eligibleContext(notificationAuthorizationStatus: .denied)

        XCTAssertEqual(
            journey.evaluate(context: context, state: freshState(), allStates: [freshState()]),
            .notEligible(.notificationPermissionDenied)
        )
    }

    func testNotEligibleWhenNotificationStatusUnknown() {
        let context = eligibleContext(notificationAuthorizationStatus: .unknown)

        XCTAssertEqual(
            journey.evaluate(context: context, state: freshState(), allStates: [freshState()]),
            .notEligible(.custom("notificationStatusUnknown"))
        )
    }

    func testNotEligibleWhenCampaignDeclined() {
        var state = freshState()
        state.status = .declined

        XCTAssertEqual(
            journey.evaluate(context: eligibleContext(), state: state, allStates: [state]),
            .notEligible(.alreadyDeclined)
        )
    }

    func testOpportunityAsksForReminderPermission() {
        let context = eligibleContext()
        let state = freshState()

        guard let opportunity = journey.makeOpportunity(context: context, state: state, allStates: [state]) else {
            return XCTFail("Expected opportunity")
        }

        XCTAssertEqual(opportunity.campaignID, RecurringReminderJourney.campaignID)
        XCTAssertEqual(opportunity.priority, 4)
        XCTAssertEqual(opportunity.primaryAction, .requestNotificationPermission)
        XCTAssertEqual(opportunity.sheetModel.title, "Get a reminder before it's due")
        XCTAssertEqual(
            opportunity.sheetModel.description,
            "We'll remind you before this transaction happens next time, so you can keep your funds ready."
        )
        XCTAssertEqual(opportunity.sheetModel.primaryButton.title, "Yes, remind me")
        XCTAssertEqual(opportunity.sheetModel.secondaryButton?.title, "Not Now")
    }

    func testCompletionRequiresReminderEnabled() {
        var state = freshState()
        state = CampaignStateTransition.markPresented(state, at: fixedDate)

        let rejected = journey.applyOutcome(
            .completed,
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext()
        )
        XCTAssertEqual(rejected.status, .presented)

        let completed = journey.applyOutcome(
            .completed,
            to: state,
            at: fixedDate,
            validationContext: CompletionValidationContext(isReminderEnabled: true)
        )
        XCTAssertEqual(completed.status, .completed)
    }
}
