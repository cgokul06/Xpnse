//
//  JourneyDependencyEvaluatorTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class JourneyDependencyEvaluatorTests: XCTestCase {
    private let prerequisiteJourneyID = "income_setup"
    private let dependentJourneyID = "custom_category"

    private func completedState(for campaignID: String) -> CampaignState {
        var state = CampaignState.fresh(campaignID: campaignID)
        state.status = .completed
        return state
    }

    private func presentedState(for campaignID: String) -> CampaignState {
        var state = CampaignState.fresh(campaignID: campaignID)
        state.status = .presented
        return state
    }

    func testNoPrerequisitesIsSatisfied() {
        let snapshot = CampaignStatesSnapshot.from([])

        XCTAssertNil(
            JourneyDependencyEvaluator.firstUnsatisfied(prerequisites: [], states: snapshot)
        )
    }

    func testSatisfiedCompletedPrerequisite() {
        let prerequisites = [JourneyPrerequisite.completed(prerequisiteJourneyID)]
        let snapshot = CampaignStatesSnapshot.from([completedState(for: prerequisiteJourneyID)])

        XCTAssertNil(
            JourneyDependencyEvaluator.firstUnsatisfied(prerequisites: prerequisites, states: snapshot)
        )
    }

    func testMissingPrerequisiteWhenStateAbsent() {
        let prerequisites = [JourneyPrerequisite.completed(prerequisiteJourneyID)]
        let snapshot = CampaignStatesSnapshot.from([])

        XCTAssertEqual(
            JourneyDependencyEvaluator.firstUnsatisfied(prerequisites: prerequisites, states: snapshot),
            .missingPrerequisite(journeyID: prerequisiteJourneyID)
        )
    }

    func testPrerequisiteNotCompletedWhenStatusDoesNotMatch() {
        let prerequisites = [JourneyPrerequisite.completed(prerequisiteJourneyID)]
        let snapshot = CampaignStatesSnapshot.from([presentedState(for: prerequisiteJourneyID)])

        XCTAssertEqual(
            JourneyDependencyEvaluator.firstUnsatisfied(prerequisites: prerequisites, states: snapshot),
            .prerequisiteNotCompleted(
                journeyID: prerequisiteJourneyID,
                requiredStatus: .completed,
                actualStatus: .presented
            )
        )
    }

    func testMultiplePrerequisitesReturnsFirstUnsatisfied() {
        let prerequisites = [
            JourneyPrerequisite.completed(prerequisiteJourneyID),
            JourneyPrerequisite.completed(dependentJourneyID)
        ]
        let snapshot = CampaignStatesSnapshot.from([
            completedState(for: prerequisiteJourneyID)
        ])

        XCTAssertEqual(
            JourneyDependencyEvaluator.firstUnsatisfied(prerequisites: prerequisites, states: snapshot),
            .missingPrerequisite(journeyID: dependentJourneyID)
        )
    }

    func testUnknownPrerequisiteJourneyID() {
        let prerequisites = [JourneyPrerequisite.completed("unknown_journey")]
        let snapshot = CampaignStatesSnapshot.from([completedState(for: prerequisiteJourneyID)])

        XCTAssertEqual(
            JourneyDependencyEvaluator.firstUnsatisfied(prerequisites: prerequisites, states: snapshot),
            .missingPrerequisite(journeyID: "unknown_journey")
        )
    }

    func testEvaluationIsDeterministic() {
        let prerequisites = [JourneyPrerequisite.completed(prerequisiteJourneyID)]
        let snapshot = CampaignStatesSnapshot.from([presentedState(for: prerequisiteJourneyID)])

        let first = JourneyDependencyEvaluator.firstUnsatisfied(prerequisites: prerequisites, states: snapshot)
        let second = JourneyDependencyEvaluator.firstUnsatisfied(prerequisites: prerequisites, states: snapshot)

        XCTAssertEqual(first, second)
        XCTAssertEqual(
            first,
            .prerequisiteNotCompleted(
                journeyID: prerequisiteJourneyID,
                requiredStatus: .completed,
                actualStatus: .presented
            )
        )
    }
}
