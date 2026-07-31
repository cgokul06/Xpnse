//
//  UserSatisfactionEngineTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

@MainActor
final class UserSatisfactionEngineTests: XCTestCase {
    private var clock: ControllableClock!
    private var store: InMemoryReviewStateStore!
    private var analytics: RecordingSatisfactionAnalytics!
    private var version: FixedAppVersionProvider!
    /// Retain engines for the suite lifetime to avoid MainActor deinit crashes
    /// under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
    private static var retainedEngines: [UserSatisfactionEngine] = []
    private static var retainedCoordinators: [UserEngagementCoordinator] = []

    override func setUp() async throws {
        clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        store = InMemoryReviewStateStore()
        analytics = RecordingSatisfactionAnalytics()
        version = FixedAppVersionProvider(shortVersion: "1.0.0", buildNumber: "1")
    }

    private func makeEngine(state: ReviewState? = nil) -> UserSatisfactionEngine {
        if let state {
            store.save(state)
        }
        let engine = UserSatisfactionEngine(
            store: store,
            clock: clock,
            versionProvider: version,
            analytics: analytics,
            triggers: TriggerCoordinator()
        )
        Self.retainedEngines.append(engine)
        return engine
    }

    private func retain(_ engine: UserSatisfactionEngine) -> UserSatisfactionEngine {
        Self.retainedEngines.append(engine)
        return engine
    }

    private func makeCoordinator(engine: UserSatisfactionEngine) -> UserEngagementCoordinator {
        let coordinator = UserEngagementCoordinator(clock: clock)
        coordinator.attach(engine: engine)
        Self.retainedCoordinators.append(coordinator)
        return coordinator
    }

    private func eligibleState(now: Date) -> ReviewState {
        var state = ReviewState.fresh(now: now.addingTimeInterval(-8 * 24 * 60 * 60), appVersion: version.shortVersion)
        state.launchCount = 8
        state.lifetimeTransactions = 20
        state.activeUsageDays = 8
        state.currentStreak = 1
        return state
    }

    func testEligibilityFailsBeforeThresholds() {
        let engine = makeEngine()
        engine.track(.transactionAdded)
        XCTAssertNil(engine.pendingReviewOpportunity)
        XCTAssertTrue(analytics.events.contains { $0.0 == .eligibilityFailed })
    }

    func testActiveUsageDayDedupedSameDay() {
        var state = eligibleState(now: clock.now())
        state.launchCount = 0
        state.activeUsageDays = 0
        state.lastActiveDay = nil
        let engine = makeEngine(state: state)
        engine.track(.appLaunched)
        engine.track(.appLaunched)
        engine.track(.appBecameActive)
        let loaded = store.load()
        XCTAssertEqual(loaded?.activeUsageDays, 1)
        XCTAssertEqual(loaded?.launchCount, 2)
    }

    func testTransactionMilestoneCyclicalReset() {
        var state = eligibleState(now: clock.now())
        state.reviewTransactionCounter = 499
        state.firedTransactionMilestones = [20, 50, 100, 250]
        let engine = makeEngine(state: state)

        engine.track(.transactionAdded)

        let loaded = store.load()!
        XCTAssertEqual(loaded.reviewTransactionCounter, 0)
        XCTAssertTrue(loaded.firedTransactionMilestones.isEmpty)
        XCTAssertEqual(loaded.lifetimeTransactions, 21)
        XCTAssertEqual(engine.pendingReviewOpportunity?.trigger, .transactionMilestone)
        XCTAssertEqual(engine.pendingReviewOpportunity?.milestone, 500)
    }

    func testMidCycleMilestoneDoesNotReset() {
        var state = eligibleState(now: clock.now())
        state.reviewTransactionCounter = 19
        let engine = makeEngine(state: state)
        engine.track(.transactionAdded)
        let loaded = store.load()!
        XCTAssertEqual(loaded.reviewTransactionCounter, 20)
        XCTAssertEqual(loaded.firedTransactionMilestones, [20])
        XCTAssertEqual(loaded.lifetimeTransactions, 21)
        XCTAssertEqual(engine.pendingReviewOpportunity?.milestone, 20)
    }

    func testReceiptCycleResetAt100() {
        var state = eligibleState(now: clock.now())
        state.reviewReceiptCounter = 99
        state.firedReceiptMilestones = [20, 50]
        let engine = makeEngine(state: state)
        engine.track(.receiptScanned)
        let loaded = store.load()!
        XCTAssertEqual(loaded.reviewReceiptCounter, 0)
        XCTAssertTrue(loaded.firedReceiptMilestones.isEmpty)
        XCTAssertEqual(loaded.lifetimeReceiptScans, 1)
        XCTAssertEqual(engine.pendingReviewOpportunity?.trigger, .receiptMilestone)
    }

    func testAppStoreOpenedStopsPermanently() {
        var state = eligibleState(now: clock.now())
        state.reviewTransactionCounter = 19
        let engine = makeEngine(state: state)
        engine.track(.appStoreReviewOpened)
        engine.track(.transactionAdded)
        XCTAssertNil(engine.pendingReviewOpportunity)
        XCTAssertEqual(store.load()?.appStoreOpened, true)
    }

    func testCriticalErrorBlocksSession() {
        var state = eligibleState(now: clock.now())
        state.reviewTransactionCounter = 19
        let engine = makeEngine(state: state)
        engine.track(.criticalErrorOccurred)
        engine.track(.transactionAdded)
        XCTAssertNil(engine.pendingReviewOpportunity)
    }

    func testCoordinatorPresentationGateRequiresSixtySecondsAndSettle() {
        var state = eligibleState(now: clock.now())
        state.reviewTransactionCounter = 19
        let engine = makeEngine(state: state)
        let coordinator = makeCoordinator(engine: engine)
        engine.track(.transactionAdded)
        XCTAssertNotNil(engine.pendingReviewOpportunity)
        XCTAssertNil(coordinator.presentedEngagement)

        coordinator.noteAppBecameActive()
        coordinator.markSettledPastLaunch()
        coordinator.reconcile()
        XCTAssertNil(coordinator.presentedEngagement)

        clock.advance(by: 59)
        coordinator.checkPresentationGate()
        XCTAssertNil(coordinator.presentedEngagement)

        clock.advance(by: 2)
        coordinator.checkPresentationGate()
        XCTAssertNotNil(coordinator.presentedEngagement)
    }

    func testCoordinatorBusyWorkDefersPresentation() {
        var state = eligibleState(now: clock.now())
        state.reviewTransactionCounter = 19
        let engine = makeEngine(state: state)
        let coordinator = makeCoordinator(engine: engine)
        engine.track(.transactionAdded)
        coordinator.reconcile()
        coordinator.noteAppBecameActive()
        coordinator.markSettledPastLaunch()
        coordinator.beginBusyWork(.addOrEditTransaction)
        clock.advance(by: 61)
        coordinator.checkPresentationGate()
        XCTAssertNil(coordinator.presentedEngagement)

        coordinator.endBusyWork(.addOrEditTransaction)
        XCTAssertNotNil(coordinator.presentedEngagement)
    }

    func testCoordinatorBackgroundResetsContinuousUsage() {
        var state = eligibleState(now: clock.now())
        state.reviewTransactionCounter = 19
        let engine = makeEngine(state: state)
        let coordinator = makeCoordinator(engine: engine)
        engine.track(.transactionAdded)
        coordinator.reconcile()
        coordinator.noteAppBecameActive()
        coordinator.markSettledPastLaunch()
        clock.advance(by: 50)
        coordinator.noteAppEnteredBackground()
        coordinator.noteAppBecameActive()
        clock.advance(by: 50)
        coordinator.checkPresentationGate()
        XCTAssertNil(coordinator.presentedEngagement)

        clock.advance(by: 15)
        coordinator.checkPresentationGate()
        XCTAssertNotNil(coordinator.presentedEngagement)
    }

    func testDismissCooldownThirtyDays() {
        var state = eligibleState(now: clock.now())
        state.reviewTransactionCounter = 19
        let engine = makeEngine(state: state)
        engine.track(.transactionAdded)
        engine.track(.reviewPromptDismissed)

        var after = store.load()!
        after.reviewTransactionCounter = 49
        store.save(after)
        let engine2 = makeEngine(state: store.load())
        engine2.track(.transactionAdded)
        XCTAssertTrue(analytics.events.contains { $0.0 == .eligibilityFailed && $0.1["reason"] == "cooldown" })

        clock.advance(by: 31 * 24 * 60 * 60)
        var ready = store.load()!
        ready.reviewTransactionCounter = 49
        store.save(ready)
        let engine3 = retain(UserSatisfactionEngine(
            store: store,
            clock: clock,
            versionProvider: version,
            analytics: analytics
        ))
        engine3.track(.transactionAdded)
        XCTAssertEqual(engine3.pendingReviewOpportunity?.milestone, 50)
    }

    func testFeedbackSubmittedWaitsForNextVersion() {
        let mutableVersion = MutableAppVersionProvider(shortVersion: "1.0.0", buildNumber: "1")
        var state = eligibleState(now: clock.now())
        state.feedbackSubmitted = true
        state.lastPromptVersion = "1.0.0"
        state.reviewRequested = true
        state.lastPromptDate = clock.now()
        state.reviewTransactionCounter = 19
        store.save(state)
        let engine = retain(UserSatisfactionEngine(
            store: store,
            clock: clock,
            versionProvider: mutableVersion,
            analytics: analytics
        ))
        engine.track(.transactionAdded)
        XCTAssertTrue(analytics.events.contains { $0.0 == .eligibilityFailed })

        analytics.reset()
        mutableVersion.shortVersion = "1.1.0"
        mutableVersion.buildNumber = "2"
        var s = store.load()!
        s.reviewTransactionCounter = 19
        s.lastPromptDate = clock.now().addingTimeInterval(-40 * 24 * 60 * 60)
        store.save(s)
        let analytics2 = RecordingSatisfactionAnalytics()
        let engine2 = retain(UserSatisfactionEngine(
            store: store,
            clock: clock,
            versionProvider: mutableVersion,
            analytics: analytics2
        ))
        engine2.track(.transactionAdded)
        XCTAssertTrue(analytics2.events.contains { $0.0 == .triggerTransactionMilestone })
        XCTAssertNotNil(engine2.pendingReviewOpportunity)
    }

    func testSevenDayStreakTrigger() {
        var state = eligibleState(now: clock.now())
        state.currentStreak = 7
        state.sevenDayStreakTriggerFired = false
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        state.lastActiveDay = formatter.string(from: clock.now())
        let engine = makeEngine(state: state)
        engine.track(.appBecameActive)
        XCTAssertTrue(analytics.events.contains { $0.0 == .triggerSevenDayStreak })
        XCTAssertEqual(store.load()?.sevenDayStreakTriggerFired, true)
        XCTAssertEqual(engine.pendingReviewOpportunity?.trigger, .sevenDayStreak)
    }

    func testInsightsTriggerOnce() {
        var state = eligibleState(now: clock.now())
        let engine = makeEngine(state: state)
        engine.track(.insightsGenerated)
        engine.track(.insightsGenerated)
        let insightEvents = analytics.events.filter { $0.0 == .triggerInsights }
        XCTAssertEqual(insightEvents.count, 1)
        XCTAssertEqual(engine.pendingReviewOpportunity?.trigger, .insightsGenerated)
    }

    func testTriggerPriorityInsightsOverTransaction() {
        var state = eligibleState(now: clock.now())
        state.currentStreak = 7
        state.reviewTransactionCounter = 20
        let coordinator = TriggerCoordinator()
        let match = coordinator.evaluate(state: state, event: .insightsGenerated)
        XCTAssertEqual(match?.analyticsEvent, .triggerInsights)
    }

    func testCycleMaxResetsWhenIneligible() {
        var state = ReviewState.fresh(now: clock.now(), appVersion: "1.0.0")
        state.reviewTransactionCounter = 499
        state.lifetimeTransactions = 5
        state.launchCount = 2
        let engine = makeEngine(state: state)
        engine.track(.transactionAdded)
        XCTAssertEqual(store.load()?.reviewTransactionCounter, 0)
        XCTAssertEqual(store.load()?.lifetimeTransactions, 6)
        XCTAssertNil(engine.pendingReviewOpportunity)
    }

    func testOpportunityCopyForTransactionMilestone() {
        var state = eligibleState(now: clock.now())
        state.reviewTransactionCounter = 49
        let engine = makeEngine(state: state)
        engine.track(.transactionAdded)
        XCTAssertEqual(
            engine.pendingReviewOpportunity?.title,
            "You've successfully tracked 50 expenses!"
        )
    }
}
