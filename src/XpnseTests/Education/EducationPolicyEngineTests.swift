//
//  EducationPolicyEngineTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class EducationPolicyEngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let engine = EducationPolicyEngine()
    private let context = CampaignContext(evaluationDate: Date(timeIntervalSince1970: 1_700_000_000))

    func testFreshPolicyAllowsFirstSession() {
        let decision = engine.evaluate(
            policy: .fresh,
            runtime: .idle,
            event: .appLaunched,
            context: context,
            now: now
        )

        XCTAssertEqual(decision, .allowed)
    }

    func testActiveRuntimeBlocksNewSession() {
        let decision = engine.evaluate(
            policy: .fresh,
            runtime: .presenting(journeyID: "income_setup"),
            event: .appBecameActive,
            context: context,
            now: now
        )

        XCTAssertEqual(decision, .blocked(.journeyAlreadyActive))
    }

    func testActivePersistedSessionBlocksNewSession() {
        var policy = EducationPolicyState.fresh
        policy.sessionActive = true

        let decision = engine.evaluate(
            policy: policy,
            runtime: .idle,
            event: .appLaunched,
            context: context,
            now: now
        )

        XCTAssertEqual(decision, .blocked(.educationSessionActive))
    }

    func testStartingSessionMarksPolicyActive() {
        let started = engine.startingSession(
            policy: .fresh,
            journeyID: "income_setup",
            context: context,
            now: now
        )

        XCTAssertTrue(started.sessionActive)
        XCTAssertEqual(started.lastPresentedJourneyID, "income_setup")
        XCTAssertNotNil(started.currentSessionID)
        XCTAssertEqual(started.currentSession?.journeyID, "income_setup")
        XCTAssertFalse(started.awaitingEvaluationTrigger)
    }

    func testEndingSessionStartsCooldownAndWaitsForTrigger() {
        let started = engine.startingSession(
            policy: .fresh,
            journeyID: "income_setup",
            context: context,
            now: now
        )
        let ended = engine.endingSession(
            policy: started,
            outcome: .declined,
            context: context,
            now: now
        )

        XCTAssertFalse(ended.sessionActive)
        XCTAssertNil(ended.currentSessionID)
        XCTAssertEqual(ended.lastJourneyOutcome, .declined)
        XCTAssertTrue(ended.awaitingEvaluationTrigger)
        XCTAssertEqual(ended.lastEducationTimestamp, now)
    }

    func testCompletedBlocksImmediateFollowUpUntilTrigger() {
        let policy = endedSession(outcome: .completed)

        XCTAssertEqual(
            engine.evaluate(policy: policy, runtime: .idle, event: .journeyOutcomeApplied(campaignID: "income_setup"), context: context, now: now),
            .blocked(.waitingForEvaluationTrigger)
        )
        XCTAssertEqual(
            engine.evaluate(policy: policy, runtime: .idle, event: .appBecameActive, context: context, now: now),
            .allowed
        )
    }

    func testCompletedAllowsReturnedToHome() {
        let policy = endedSession(outcome: .completed)

        XCTAssertEqual(
            engine.evaluate(policy: policy, runtime: .idle, event: .returnedToHome, context: context, now: now),
            .allowed
        )
    }

    func testDeclinedDoesNotAllowReturnedToHome() {
        let policy = endedSession(outcome: .declined)

        XCTAssertEqual(
            engine.evaluate(policy: policy, runtime: .idle, event: .returnedToHome, context: context, now: now),
            .blocked(.declineCooldown)
        )
    }

    func testRecurringCreatedIsASessionStartTrigger() {
        let policy = endedSession(outcome: .completed)

        XCTAssertEqual(
            engine.evaluate(policy: policy, runtime: .idle, event: .recurringTransactionCreated, context: context, now: now),
            .allowed
        )
    }

    func testDismissedWaitsForNextTrigger() {
        let policy = endedSession(outcome: .dismissed)

        XCTAssertEqual(
            engine.evaluate(policy: policy, runtime: .idle, event: .journeyOutcomeApplied(campaignID: "income_setup"), context: context, now: now),
            .blocked(.waitingForEvaluationTrigger)
        )
        XCTAssertEqual(
            engine.evaluate(policy: policy, runtime: .idle, event: .transactionAdded, context: context, now: now),
            .allowed
        )
    }

    func testActionFailedWaitsForNextTrigger() {
        let policy = endedSession(outcome: .actionFailed)

        XCTAssertEqual(
            engine.evaluate(policy: policy, runtime: .idle, event: .journeyOutcomeApplied(campaignID: "income_setup"), context: context, now: now),
            .blocked(.waitingForEvaluationTrigger)
        )
        XCTAssertEqual(
            engine.evaluate(policy: policy, runtime: .idle, event: .appLaunched, context: context, now: now),
            .allowed
        )
    }

    func testDeclinedBlocksUntilTenMinutesEvenWithTrigger() {
        let policy = endedSession(outcome: .declined)
        let fiveMinutesLater = now.addingTimeInterval(5 * 60)

        XCTAssertEqual(
            engine.evaluate(policy: policy, runtime: .idle, event: .appBecameActive, context: context, now: fiveMinutesLater),
            .blocked(.declineCooldown)
        )
    }

    func testFollowUpAfterSkipIgnoresDeclineCooldownOnForegroundOrLaunch() {
        let policy = endedSession(outcome: .declined)
        let oneMinuteLater = now.addingTimeInterval(60)

        for event in [EducationEvent.appBecameActive, .appLaunched] {
            XCTAssertEqual(
                engine.evaluate(
                    policy: policy,
                    runtime: .idle,
                    event: event,
                    context: context,
                    now: oneMinuteLater,
                    followUpAfterSkipOf: "income_setup"
                ),
                .allowed
            )
        }
    }

    func testFollowUpAfterSkipStillNeedsForegroundOrLaunch() {
        let policy = endedSession(outcome: .declined)

        for event in [EducationEvent.returnedToHome, .transactionAdded, .journeyOutcomeApplied(campaignID: "income_setup")] {
            XCTAssertEqual(
                engine.evaluate(
                    policy: policy,
                    runtime: .idle,
                    event: event,
                    context: context,
                    now: now,
                    followUpAfterSkipOf: "income_setup"
                ),
                .blocked(.waitingForEvaluationTrigger)
            )
        }
    }

    func testFollowUpOfDifferentJourneyKeepsDeclineCooldown() {
        let policy = endedSession(outcome: .declined)

        XCTAssertEqual(
            engine.evaluate(
                policy: policy,
                runtime: .idle,
                event: .appBecameActive,
                context: context,
                now: now.addingTimeInterval(60),
                followUpAfterSkipOf: "some_other_journey"
            ),
            .blocked(.declineCooldown)
        )
    }

    func testDeclinedAllowsAfterTenMinutesAndTrigger() {
        let policy = endedSession(outcome: .declined)
        let tenMinutesLater = now.addingTimeInterval(EducationPolicyConfiguration.defaultDeclineMinimumElapsedTime)

        XCTAssertEqual(
            engine.evaluate(
                policy: policy,
                runtime: .idle,
                event: .journeyOutcomeApplied(campaignID: "income_setup"),
                context: context,
                now: tenMinutesLater
            ),
            .blocked(.waitingForEvaluationTrigger)
        )
        XCTAssertEqual(
            engine.evaluate(policy: policy, runtime: .idle, event: .appLaunched, context: context, now: tenMinutesLater),
            .allowed
        )
    }

    func testMinimumLaunchCountStrategy() {
        let configured = EducationPolicyEngine(
            configuration: EducationPolicyConfiguration(
                completed: .none,
                declined: .minimumAppLaunchCount(2),
                dismissed: .none,
                actionFailed: .none,
                sessionStartTriggers: [.appLaunched]
            )
        )
        var policy = endedSession(outcome: .declined)
        policy.lastEducationAppLaunchCount = 3
        policy.appLaunchCount = 4

        XCTAssertEqual(
            configured.evaluate(policy: policy, runtime: .idle, event: .appLaunched, context: context, now: now),
            .blocked(.declineCooldown)
        )

        policy.appLaunchCount = 5
        XCTAssertEqual(
            configured.evaluate(policy: policy, runtime: .idle, event: .appLaunched, context: context, now: now),
            .allowed
        )
    }

    func testMinimumActiveDaysAndTransactionsStrategies() {
        let configured = EducationPolicyEngine(
            configuration: EducationPolicyConfiguration(
                completed: .anyOf([
                    .minimumActiveDays(1),
                    .minimumTransactions(3)
                ]),
                declined: .none,
                dismissed: .none,
                actionFailed: .none,
                sessionStartTriggers: [.appLaunched]
            )
        )
        var policy = endedSession(outcome: .completed)
        policy.lastEducationActiveDayCount = 1
        policy.activeDayCount = 1
        policy.lastEducationTransactionCount = 0

        let fewTransactions = CampaignContext(transactionCount: 2, evaluationDate: now)
        XCTAssertEqual(
            configured.evaluate(policy: policy, runtime: .idle, event: .appLaunched, context: fewTransactions, now: now),
            .blocked(.completionCooldown)
        )

        policy.activeDayCount = 2
        XCTAssertEqual(
            configured.evaluate(policy: policy, runtime: .idle, event: .appLaunched, context: fewTransactions, now: now),
            .allowed
        )
    }

    func testUntilNextLaunchAndForegroundStrategies() {
        let configured = EducationPolicyEngine(
            configuration: EducationPolicyConfiguration(
                completed: .untilNextLaunch,
                declined: .untilNextForeground,
                dismissed: .none,
                actionFailed: .none,
                sessionStartTriggers: [.appLaunched, .appBecameActive]
            )
        )
        let completed = endedSession(outcome: .completed)
        XCTAssertEqual(
            configured.evaluate(policy: completed, runtime: .idle, event: .appBecameActive, context: context, now: now),
            .blocked(.waitingForEvaluationTrigger)
        )
        XCTAssertEqual(
            configured.evaluate(policy: completed, runtime: .idle, event: .appLaunched, context: context, now: now),
            .allowed
        )

        let declined = endedSession(outcome: .declined)
        XCTAssertEqual(
            configured.evaluate(policy: declined, runtime: .idle, event: .appLaunched, context: context, now: now),
            .blocked(.waitingForEvaluationTrigger)
        )
        XCTAssertEqual(
            configured.evaluate(policy: declined, runtime: .idle, event: .appBecameActive, context: context, now: now),
            .allowed
        )
    }

    func testRecordingUsageIncrementsLaunchAndActiveDays() {
        var policy = EducationPolicyState.fresh
        policy = engine.recordingUsage(policy: policy, event: .appLaunched, now: now)
        XCTAssertEqual(policy.appLaunchCount, 1)
        XCTAssertEqual(policy.activeDayCount, 1)

        policy = engine.recordingUsage(policy: policy, event: .appBecameActive, now: now)
        XCTAssertEqual(policy.appLaunchCount, 1)
        XCTAssertEqual(policy.activeDayCount, 1)

        let nextDay = now.addingTimeInterval(86_400)
        policy = engine.recordingUsage(policy: policy, event: .appBecameActive, now: nextDay)
        XCTAssertEqual(policy.activeDayCount, 2)
    }

    func testClearingAbandonedSession() {
        var policy = EducationPolicyState.fresh
        policy.sessionActive = true
        policy.currentSessionID = UUID()
        policy.lastPresentedJourneyID = "income_setup"

        let cleared = engine.clearingAbandonedSession(policy)
        XCTAssertFalse(cleared.sessionActive)
        XCTAssertNil(cleared.currentSessionID)
        XCTAssertEqual(cleared.lastPresentedJourneyID, "income_setup")
    }

    func testPolicyStateRoundTrip() {
        let store = InMemoryEducationPolicyStateStore()
        var state = EducationPolicyState.fresh
        state.lastPresentedJourneyID = "custom_category"
        state.lastJourneyOutcome = .declined
        state.lastEducationTimestamp = now
        state.sessionActive = false
        state.awaitingEvaluationTrigger = true
        state.appLaunchCount = 4

        store.save(state)
        XCTAssertEqual(store.load(), state)
    }

    func testUserDefaultsPolicyStoreRoundTrip() {
        let defaults = UserDefaults(suiteName: "education.policy.tests.\(UUID().uuidString)")!
        let store = UserDefaultsEducationPolicyStateStore(defaults: defaults)
        var state = EducationPolicyState.fresh
        state.lastJourneyOutcome = .dismissed
        state.awaitingEvaluationTrigger = true
        store.save(state)

        XCTAssertEqual(store.load()?.lastJourneyOutcome, .dismissed)
        XCTAssertEqual(store.load()?.awaitingEvaluationTrigger, true)
    }

    func testDecisionDebugDescriptions() {
        XCTAssertEqual(EducationPolicyDecision.allowed.debugDescription, "Policy Allowed")
        XCTAssertEqual(
            EducationPolicyDecision.blocked(.declineCooldown).debugDescription,
            "Policy Blocked: Decline Cooldown"
        )
        XCTAssertEqual(
            EducationPolicyReason.waitingForEvaluationTrigger.debugDescription,
            "Waiting For Next Trigger"
        )
    }

    private func endedSession(outcome: CampaignOutcome) -> EducationPolicyState {
        let started = engine.startingSession(
            policy: .fresh,
            journeyID: "income_setup",
            context: context,
            now: now
        )
        return engine.endingSession(
            policy: started,
            outcome: outcome,
            context: context,
            now: now
        )
    }
}
