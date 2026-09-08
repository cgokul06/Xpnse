//
//  CampaignStateTransitionTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class CampaignStateTransitionTests: XCTestCase {
    private let campaignID = "test_campaign"
    private let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
    private let secondDate = Date(timeIntervalSince1970: 1_700_086_400)

    func testMarkPresentedFromNotStarted() {
        let fresh = CampaignState.fresh(campaignID: campaignID)
        let presented = CampaignStateTransition.markPresented(fresh, at: firstDate)

        XCTAssertEqual(presented.status, .presented)
        XCTAssertEqual(presented.presentationCount, 1)
        XCTAssertEqual(presented.firstPresentedDate, firstDate)
        XCTAssertEqual(presented.lastPresentedDate, firstDate)
        XCTAssertNil(presented.completedDate)
        XCTAssertNil(presented.declinedDate)
    }

    func testMarkPresentedIncrementsCountAndUpdatesLastDate() {
        var state = CampaignState.fresh(campaignID: campaignID)
        state = CampaignStateTransition.markPresented(state, at: firstDate)
        state = CampaignStateTransition.markPresented(state, at: secondDate)

        XCTAssertEqual(state.presentationCount, 2)
        XCTAssertEqual(state.firstPresentedDate, firstDate)
        XCTAssertEqual(state.lastPresentedDate, secondDate)
    }

    func testCompletedOutcome() {
        var state = CampaignState.fresh(campaignID: campaignID)
        state = CampaignStateTransition.markPresented(state, at: firstDate)
        let completed = CampaignStateTransition.applying(
            outcome: .completed,
            to: state,
            at: secondDate
        )

        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(completed.completedDate, secondDate)
        XCTAssertNil(completed.declinedDate)
    }

    func testDeclinedOutcome() {
        var state = CampaignState.fresh(campaignID: campaignID)
        state = CampaignStateTransition.markPresented(state, at: firstDate)
        let declined = CampaignStateTransition.applying(
            outcome: .declined,
            to: state,
            at: secondDate
        )

        XCTAssertEqual(declined.status, .declined)
        XCTAssertEqual(declined.declinedDate, secondDate)
        XCTAssertNil(declined.completedDate)
    }

    func testDismissedOutcomeKeepsPresentedAndIncrementsDismissCount() {
        var state = CampaignState.fresh(campaignID: campaignID)
        state = CampaignStateTransition.markPresented(state, at: firstDate)
        let dismissed = CampaignStateTransition.applying(
            outcome: .dismissed,
            to: state,
            at: secondDate
        )

        XCTAssertEqual(dismissed.status, .presented)
        XCTAssertEqual(dismissed.dismissedCount, 1)
        XCTAssertEqual(dismissed.presentationCount, 1)
        XCTAssertNil(dismissed.completedDate)
        XCTAssertNil(dismissed.declinedDate)
    }

    func testActionFailedOutcomeDoesNotChangeState() {
        var state = CampaignState.fresh(campaignID: campaignID)
        state = CampaignStateTransition.markPresented(state, at: firstDate)
        let failed = CampaignStateTransition.applying(
            outcome: .actionFailed,
            to: state,
            at: secondDate
        )

        XCTAssertEqual(failed, state)
    }
}
