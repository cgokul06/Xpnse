//
//  ExpenseReminderScheduleTests.swift
//  XpnseTests
//

import XCTest
import UserNotifications
@testable import Xpnse

@MainActor
final class ExpenseReminderScheduleTests: XCTestCase {
    private let policy = ExpenseReminderPolicy.current

    func testFreshInstallDoesNotScheduleUntilTheUserLeaves() async throws {
        let env = Environment(now: date(2026, 6, 1, 10))
        await env.scheduler.handleDidBecomeActive()

        XCTAssertEqual(env.store.lastActiveAt, env.clock.now())
        XCTAssertTrue(env.center.pendingItems.isEmpty)
        XCTAssertEqual(env.analytics.scheduledCount, 0)

        await env.scheduler.handleDidEnterBackground()

        let pending = try XCTUnwrap(env.center.expenseReminder)
        XCTAssertEqual(env.center.pendingItems.filter { $0.identifier == policy.notificationIdentifier }.count, 1)
        XCTAssertEqual(pending.fireDate, date(2026, 6, 2, 19))
        XCTAssertEqual(pending.title, "A quick expense check-in")
        XCTAssertEqual(
            pending.body,
            "Had any expenses recently? Take a moment to log them in SnapLedger and keep your spending records up to date."
        )
        XCTAssertEqual(pending.userInfoKind, ExpenseReminderPolicy.userInfoKind)
        XCTAssertGreaterThanOrEqual(pending.fireDate ?? .distantPast, env.clock.now().addingTimeInterval(policy.inactivityThreshold))
    }

    func testDebugScheduleFiresThirtyMinutesAfterLeaving() async throws {
        let env = Environment(now: date(2026, 6, 1, 10), policy: .debug)
        await env.scheduler.handleDidBecomeActive()
        await env.scheduler.handleDidEnterBackground()

        let pending = try XCTUnwrap(env.center.expenseReminder)
        XCTAssertEqual(pending.fireDate, date(2026, 6, 1, 10, 30))
        XCTAssertFalse(ExpenseReminderPolicy.debug.deliversAtNextEvening)
        XCTAssertEqual(ExpenseReminderPolicy.debug.inactivityThreshold, 30 * 60)
        #if DEBUG
        XCTAssertEqual(ExpenseReminderPolicy.runtime, ExpenseReminderPolicy.debug)
        #endif
    }

    func testMorningOpenSchedulesTheNextEvening() {
        let calendar = Environment.utcCalendar()
        let lastActive = date(2026, 6, 1, 10, calendar: calendar)
        let duringFirstDay = date(2026, 6, 1, 18, calendar: calendar)
        let nextMorning = date(2026, 6, 2, 10, calendar: calendar)

        let sameDay = ExpenseReminderEvaluator.decide(
            evaluation(lastActive: lastActive, now: duringFirstDay, calendar: calendar),
            policy: policy,
            calendar: calendar
        )
        let next = ExpenseReminderEvaluator.decide(
            evaluation(lastActive: lastActive, now: nextMorning, calendar: calendar),
            policy: policy,
            calendar: calendar
        )

        XCTAssertEqual(sameDay.fireDate, date(2026, 6, 2, 19, calendar: calendar))
        XCTAssertEqual(next.fireDate, date(2026, 6, 2, 19, calendar: calendar))
        XCTAssertNotEqual(sameDay.fireDate, date(2026, 6, 1, 19, calendar: calendar))
        for fireDate in [sameDay.fireDate, next.fireDate] {
            XCTAssertGreaterThanOrEqual(
                fireDate ?? .distantPast,
                lastActive.addingTimeInterval(policy.inactivityThreshold)
            )
        }
    }

    func testReminderBecomesEligibleAfterTwentyFourHours() {
        let calendar = Environment.utcCalendar()
        let lastActive = date(2026, 6, 1, 10, calendar: calendar)
        let atThreshold = date(2026, 6, 2, 10, calendar: calendar)
        let afterEvening = date(2026, 6, 2, 20, calendar: calendar)

        let ready = ExpenseReminderEvaluator.decide(
            evaluation(lastActive: lastActive, now: atThreshold, calendar: calendar),
            policy: policy,
            calendar: calendar
        )
        let missedEvening = ExpenseReminderEvaluator.decide(
            evaluation(lastActive: lastActive, now: afterEvening, calendar: calendar),
            policy: policy,
            calendar: calendar
        )

        XCTAssertTrue(ready.shouldSchedule)
        XCTAssertEqual(ready.phase, .scheduled)
        XCTAssertEqual(ready.fireDate, date(2026, 6, 2, 19, calendar: calendar))
        XCTAssertEqual(missedEvening.fireDate, date(2026, 6, 3, 19, calendar: calendar))
        XCTAssertGreaterThan(missedEvening.fireDate ?? .distantPast, afterEvening)
    }

    func testDeliveryUsesTheConfiguredEveningHour() async throws {
        var custom = policy
        custom.reminderHour = 20
        let env = Environment(now: date(2026, 6, 1, 10), policy: custom)
        await env.scheduler.handleDidBecomeActive()
        await env.scheduler.handleDidEnterBackground()

        let fireDate = try XCTUnwrap(env.center.expenseReminder?.fireDate)
        XCTAssertEqual(env.calendar.component(.hour, from: fireDate), 20)
        XCTAssertEqual(env.calendar.component(.minute, from: fireDate), 0)
        XCTAssertEqual(fireDate, date(2026, 6, 2, 20))
    }

    func testEveningOpenWaitsUntilTheEveningAfterNext() {
        let calendar = Environment.utcCalendar()
        let lastActive = date(2026, 6, 1, 20, calendar: calendar)
        let decision = ExpenseReminderEvaluator.decide(
            evaluation(lastActive: lastActive, now: lastActive, calendar: calendar),
            policy: policy,
            calendar: calendar
        )

        XCTAssertEqual(decision.fireDate, date(2026, 6, 3, 19, calendar: calendar))
    }

    func testOpeningTheAppCancelsThePendingReminderAndRestartsTheWindow() async {
        let env = Environment(now: date(2026, 6, 3, 14))
        env.store.lastActiveAt = date(2026, 6, 1, 10)
        env.store.lastScheduledReminderAt = date(2026, 6, 3, 19)
        env.center.pendingItems = [
            ScheduledNotificationSnapshot(
                identifier: policy.notificationIdentifier,
                fireDate: date(2026, 6, 3, 19),
                title: "A quick expense check-in",
                body: "body",
                userInfoKind: ExpenseReminderPolicy.userInfoKind
            ),
            ScheduledNotificationSnapshot(
                identifier: "recurring-other",
                fireDate: date(2026, 6, 3, 21),
                title: "Rent",
                body: "other",
                userInfoKind: nil
            )
        ]

        await env.scheduler.handleDidBecomeActive()

        XCTAssertEqual(env.store.lastActiveAt, date(2026, 6, 3, 14))
        XCTAssertNil(env.store.lastScheduledReminderAt)
        XCTAssertEqual(env.center.pendingItems.map(\.identifier), ["recurring-other"])
        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInCancelled), 1)
        XCTAssertEqual(
            env.analytics.events.first?.parameters[AppAnalytics.Param.cancellationReason],
            ExpenseReminderCancellationReason.appOpen
        )
        XCTAssertTrue(env.center.pendingItems.allSatisfy { $0.identifier != policy.notificationIdentifier })

        await env.scheduler.handleDidEnterBackground()

        XCTAssertEqual(env.center.expenseReminder?.fireDate, date(2026, 6, 4, 19))
        XCTAssertEqual(env.center.pendingItems.filter { $0.identifier == "recurring-other" }.count, 1)
    }

    func testRepeatedOpensDoNotCreateDuplicateNotificationsOrAnalytics() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        await env.scheduler.handleDidBecomeActive()
        env.clock.advance(by: 60 * 60)
        await env.scheduler.handleDidBecomeActive()

        XCTAssertEqual(env.store.lastActiveAt, date(2026, 6, 1, 10))
        XCTAssertTrue(env.center.pendingItems.isEmpty)

        await env.scheduler.handleDidEnterBackground()
        await env.scheduler.handleDidEnterBackground()

        XCTAssertEqual(env.center.pendingItems.filter { $0.identifier == policy.notificationIdentifier }.count, 1)
        XCTAssertEqual(env.analytics.scheduledCount, 1)
        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInEligible), 1)
    }

    func testForegroundSessionDoesNotScheduleEvenAfterTheThresholdPasses() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        await env.scheduler.handleDidBecomeActive()
        env.clock.set(date(2026, 6, 4, 12))
        await env.scheduler.reconcileSchedule()

        XCTAssertTrue(env.center.pendingItems.isEmpty)
        XCTAssertEqual(env.analytics.scheduledCount, 0)
    }

    func testAddingAnExpenseDoesNotCreateAnotherNotification() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        await env.scheduler.handleDidBecomeActive()
        await env.scheduler.handleNotificationOpened()
        await env.scheduler.handleDidEnterBackground()
        let countBeforeSave = env.center.pendingItems.count

        await env.scheduler.noteExpenseAdded()
        await env.scheduler.noteExpenseAdded()

        XCTAssertEqual(env.center.pendingItems.count, countBeforeSave)
        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInConversion), 1)
    }

    func testDeniedAuthorizationPreventsSchedulingAndRemovesOnlyThisCampaign() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        env.center.status = .denied
        env.store.lastActiveAt = date(2026, 6, 1, 10)
        env.store.lastScheduledReminderAt = date(2026, 6, 3, 19)
        env.center.pendingItems = [
            ScheduledNotificationSnapshot(
                identifier: policy.notificationIdentifier,
                fireDate: date(2026, 6, 3, 19),
                title: "A quick expense check-in",
                body: "body",
                userInfoKind: ExpenseReminderPolicy.userInfoKind
            ),
            ScheduledNotificationSnapshot(
                identifier: "recurring-other",
                fireDate: date(2026, 6, 4, 9),
                title: "Other",
                body: "other",
                userInfoKind: nil
            )
        ]

        await env.scheduler.handleDidEnterBackground()

        XCTAssertEqual(env.center.pendingItems.map(\.identifier), ["recurring-other"])
        XCTAssertEqual(env.analytics.scheduledCount, 0)
        XCTAssertEqual(
            env.analytics.events.map { $0.parameters[AppAnalytics.Param.cancellationReason] },
            [ExpenseReminderCancellationReason.authorizationDenied]
        )
    }

    func testProvisionalAndEphemeralAuthorizationPermitScheduling() async {
        for status: UNAuthorizationStatus in [.provisional, .ephemeral, .authorized] {
            let env = Environment(now: date(2026, 6, 1, 10))
            env.center.status = status
            await env.scheduler.handleDidBecomeActive()
            await env.scheduler.handleDidEnterBackground()
            XCTAssertEqual(env.center.expenseReminder?.identifier, policy.notificationIdentifier, "status \(status.rawValue)")
        }
    }

    func testNotDeterminedAuthorizationDoesNotSchedule() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        env.center.status = .notDetermined
        await env.scheduler.handleDidBecomeActive()
        await env.scheduler.handleDidEnterBackground()
        XCTAssertTrue(env.center.pendingItems.isEmpty)
    }

    func testTimeZoneChangeRecalculatesTheNextDelivery() async throws {
        let env = Environment(now: date(2026, 6, 1, 10))
        await env.scheduler.handleDidBecomeActive()
        await env.scheduler.handleDidEnterBackground()
        let gmtFire = try XCTUnwrap(env.center.expenseReminder?.fireDate)
        XCTAssertEqual(gmtFire, date(2026, 6, 2, 19))

        var kolkata = Calendar(identifier: .gregorian)
        kolkata.timeZone = TimeZone(secondsFromGMT: 5 * 60 * 60 + 30 * 60)!
        env.calendar = kolkata
        await env.scheduler.reconcileSchedule()

        let moved = try XCTUnwrap(env.center.expenseReminder?.fireDate)
        XCTAssertEqual(kolkata.component(.hour, from: moved), policy.reminderHour)
        XCTAssertEqual(kolkata.component(.minute, from: moved), 0)
        XCTAssertNotEqual(moved, gmtFire)
        XCTAssertGreaterThanOrEqual(
            moved,
            date(2026, 6, 1, 10).addingTimeInterval(policy.inactivityThreshold)
        )
    }

    func testDaylightSavingTransitionKeepsTheLocalEvening() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let lastActive = date(2026, 3, 7, 10, calendar: calendar)
        let now = lastActive
        let fireDate = ExpenseReminderScheduleMath.nextFireDate(
            lastActiveAt: lastActive,
            now: now,
            policy: policy,
            calendar: calendar
        )

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate ?? .distantPast)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 8)
        XCTAssertEqual(components.hour, 19)
        XCTAssertEqual(components.minute, 0)
        XCTAssertGreaterThanOrEqual(fireDate ?? .distantPast, lastActive.addingTimeInterval(policy.inactivityThreshold))
    }

    func testSchedulingFailureStaysRecoverable() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        env.center.addError = TestSchedulingError()
        await env.scheduler.handleDidBecomeActive()
        await env.scheduler.handleDidEnterBackground()

        XCTAssertTrue(env.center.pendingItems.isEmpty)
        XCTAssertNil(env.store.lastScheduledReminderAt)
        XCTAssertEqual(env.analytics.scheduledCount, 0)
        XCTAssertEqual(
            env.analytics.count(AppAnalytics.Event.checkInScheduleResult, result: AppAnalytics.Outcome.failed.rawValue),
            1
        )

        env.center.addError = nil
        await env.scheduler.reconcileSchedule()

        XCTAssertEqual(env.center.expenseReminder?.fireDate, date(2026, 6, 2, 19))
        XCTAssertEqual(env.store.lastScheduledReminderAt, date(2026, 6, 2, 19))
        XCTAssertEqual(env.analytics.scheduledCount, 1)
        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInEligible), 1)
    }

    func testRelaunchReconcilesPendingStateWithoutDuplicateAnalytics() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        await env.scheduler.handleDidBecomeActive()
        await env.scheduler.handleDidEnterBackground()
        let scheduled = env.analytics.scheduledCount

        let relaunched = env.makeScheduler()
        await relaunched.handleDidEnterBackground()

        XCTAssertEqual(env.center.pendingItems.filter { $0.identifier == policy.notificationIdentifier }.count, 1)
        XCTAssertEqual(env.analytics.scheduledCount, scheduled)
        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInEligible), 1)
    }

    func testFailedCancellationIsNotReported() async {
        let env = Environment(now: date(2026, 6, 3, 14))
        env.center.failRemoval = true
        env.store.lastScheduledReminderAt = date(2026, 6, 3, 19)
        env.center.pendingItems = [
            ScheduledNotificationSnapshot(
                identifier: policy.notificationIdentifier,
                fireDate: date(2026, 6, 3, 19),
                title: "A quick expense check-in",
                body: "body",
                userInfoKind: ExpenseReminderPolicy.userInfoKind
            )
        ]

        await env.scheduler.handleDidBecomeActive()

        XCTAssertEqual(env.center.expenseReminder?.identifier, policy.notificationIdentifier)
        XCTAssertEqual(env.store.lastScheduledReminderAt, date(2026, 6, 3, 19))
        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInCancelled), 0)
    }

    func testDeliveredReminderIsNotReplacedUntilTheUserOpensTheApp() async {
        let env = Environment(now: date(2026, 6, 3, 19, 30))
        env.store.lastActiveAt = date(2026, 6, 1, 10)
        env.store.lastReminderDeliveredAt = date(2026, 6, 3, 19)

        await env.scheduler.handleDidEnterBackground()
        XCTAssertTrue(env.center.pendingItems.isEmpty)
        XCTAssertEqual(env.analytics.scheduledCount, 0)

        await env.scheduler.handleDidBecomeActive()
        await env.scheduler.handleDidEnterBackground()
        XCTAssertNotNil(env.center.expenseReminder)
        XCTAssertGreaterThanOrEqual(
            env.center.expenseReminder?.fireDate ?? .distantPast,
            date(2026, 6, 3, 19, 30).addingTimeInterval(policy.inactivityThreshold)
        )
    }

    func testDisablingTheReminderCancelsOnlyThisCampaign() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        env.store.lastScheduledReminderAt = date(2026, 6, 3, 19)
        env.center.pendingItems = [
            ScheduledNotificationSnapshot(
                identifier: policy.notificationIdentifier,
                fireDate: date(2026, 6, 3, 19),
                title: "A quick expense check-in",
                body: "body",
                userInfoKind: ExpenseReminderPolicy.userInfoKind
            ),
            ScheduledNotificationSnapshot(
                identifier: "recurring-other",
                fireDate: date(2026, 6, 4, 9),
                title: "Other",
                body: "other",
                userInfoKind: nil
            )
        ]

        await env.scheduler.setEnabled(false)

        XCTAssertFalse(env.store.isEnabled)
        XCTAssertEqual(env.center.pendingItems.map(\.identifier), ["recurring-other"])
        XCTAssertEqual(
            env.analytics.events.first?.parameters[AppAnalytics.Param.cancellationReason],
            ExpenseReminderCancellationReason.disabled
        )
    }

    func testProvisionalAuthorizationIsRequestedOnceAfterFirstUse() async throws {
        let env = Environment(now: date(2026, 6, 1, 10))
        env.center.status = .notDetermined
        env.completedFirstUse = false

        await env.scheduler.requestProvisionalAuthorizationIfNeeded()
        XCTAssertTrue(env.center.requestedOptions.isEmpty)
        XCTAssertFalse(env.store.didAttemptProvisionalAuthorization)

        env.completedFirstUse = true
        env.store.isEnabled = false
        await env.scheduler.requestProvisionalAuthorizationIfNeeded()
        XCTAssertTrue(env.center.requestedOptions.isEmpty)

        env.store.isEnabled = true
        await env.scheduler.requestProvisionalAuthorizationIfNeeded()
        await env.scheduler.requestProvisionalAuthorizationIfNeeded()

        XCTAssertEqual(env.center.requestedOptions.count, 1)
        let options = try XCTUnwrap(env.center.requestedOptions.first)
        XCTAssertTrue(options.contains(.alert))
        XCTAssertTrue(options.contains(.sound))
        XCTAssertTrue(options.contains(.badge))
        XCTAssertTrue(options.contains(.provisional))
        XCTAssertTrue(env.store.didAttemptProvisionalAuthorization)
        XCTAssertEqual(env.center.status, .provisional)
    }

    func testExistingAuthorizationIsNotRequestedAgain() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        env.center.status = .authorized
        await env.scheduler.requestProvisionalAuthorizationIfNeeded()
        XCTAssertTrue(env.center.requestedOptions.isEmpty)
        XCTAssertTrue(env.store.didAttemptProvisionalAuthorization)

        env.center.status = .denied
        env.store.didAttemptProvisionalAuthorization = false
        await env.scheduler.requestProvisionalAuthorizationIfNeeded()
        XCTAssertTrue(env.center.requestedOptions.isEmpty)
        XCTAssertTrue(env.store.didAttemptProvisionalAuthorization)
    }

    func testNotificationOpenAttributesOnlyTheFollowingExpenseSave() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        await env.scheduler.handleNotificationOpened()

        XCTAssertEqual(env.openedAddExpense, 1)
        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInOpened), 1)
        XCTAssertEqual(
            env.analytics.events.first?.parameters[AppAnalytics.Param.entryPoint],
            "notification"
        )
        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInConversion), 0)

        await env.scheduler.noteExpenseAdded()
        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInConversion), 1)
        XCTAssertEqual(
            env.analytics.events.last?.parameters[AppAnalytics.Param.campaignVersion],
            String(policy.campaignVersion)
        )

        await env.scheduler.noteExpenseAdded()
        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInConversion), 1)
    }

    func testConversionCountsInALaterSessionWithin24Hours() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        await env.scheduler.handleDidBecomeActive()
        await env.scheduler.handleNotificationOpened()
        await env.scheduler.handleDidEnterBackground()

        env.clock.set(date(2026, 6, 2, 9))
        let relaunched = env.makeScheduler()
        await relaunched.handleDidBecomeActive()
        await relaunched.noteExpenseAdded()
        await relaunched.noteExpenseAdded()

        let conversions = env.analytics.events(named: AppAnalytics.Event.checkInConversion)
        XCTAssertEqual(conversions.count, 1)
        XCTAssertEqual(conversions.first?.parameters[AppAnalytics.Param.window], "24h")
        XCTAssertNil(env.store.conversionAttribution)
    }

    func testConversionIsNotCountedAfterAttributionExpires() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        await env.scheduler.handleNotificationOpened()

        env.clock.set(date(2026, 6, 2, 10, 1))
        await env.scheduler.noteExpenseAdded()

        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInConversion), 0)
        XCTAssertNil(env.store.conversionAttribution)
    }

    func testLaterTapRestartsTheConversionWindow() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        await env.scheduler.handleNotificationOpened()
        env.clock.set(date(2026, 6, 2, 8))
        await env.scheduler.handleNotificationOpened()

        env.clock.set(date(2026, 6, 2, 20))
        await env.scheduler.noteExpenseAdded()

        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInConversion), 1)
    }

    func testClearingLocalDataDropsConversionAttribution() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        await env.scheduler.handleNotificationOpened()
        await env.scheduler.noteLocalDataCleared()
        await env.scheduler.noteExpenseAdded()

        XCTAssertEqual(env.analytics.count(AppAnalytics.Event.checkInConversion), 0)
    }

    func testCampaignVersionChangeDropsTheOldPendingRequest() async {
        var updated = policy
        updated.campaignVersion = 2
        let env = Environment(now: date(2026, 6, 1, 10), policy: updated)
        env.store.campaignVersion = 1
        env.store.lastScheduledReminderAt = date(2026, 6, 3, 19)
        env.center.pendingItems = [
            ScheduledNotificationSnapshot(
                identifier: policy.notificationIdentifier,
                fireDate: date(2026, 6, 3, 19),
                title: "old",
                body: "old",
                userInfoKind: ExpenseReminderPolicy.userInfoKind
            )
        ]

        await env.scheduler.handleDidBecomeActive()

        XCTAssertEqual(env.store.campaignVersion, 2)
        XCTAssertTrue(env.center.pendingItems.isEmpty)
        XCTAssertEqual(
            env.analytics.events.map { $0.parameters[AppAnalytics.Param.cancellationReason] },
            [ExpenseReminderCancellationReason.policyChanged]
        )
        XCTAssertEqual(env.analytics.scheduledCount, 0)
    }

    func testClearingLocalDataRestartsTheInactivityWindowWithoutSchedulingImmediately() async {
        let env = Environment(now: date(2026, 6, 4, 12))
        env.store.lastActiveAt = date(2026, 6, 1, 10)
        env.store.lastScheduledReminderAt = date(2026, 6, 3, 19)

        await env.scheduler.noteLocalDataCleared()

        XCTAssertEqual(env.store.lastActiveAt, date(2026, 6, 4, 12))
        XCTAssertNil(env.store.lastScheduledReminderAt)
        XCTAssertTrue(env.center.pendingItems.isEmpty)
    }

    func testIncompleteFirstUseDoesNotSchedule() async {
        let env = Environment(now: date(2026, 6, 1, 10))
        env.completedFirstUse = false
        await env.scheduler.handleDidBecomeActive()
        await env.scheduler.handleDidEnterBackground()

        XCTAssertEqual(env.store.lastActiveAt, date(2026, 6, 1, 10))
        XCTAssertTrue(env.center.pendingItems.isEmpty)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int = 0,
        calendar: Calendar? = nil
    ) -> Date {
        Environment.date(year, month, day, hour, minute, calendar: calendar ?? Environment.utcCalendar())
    }

    private func evaluation(
        lastActive: Date,
        now: Date,
        calendar: Calendar,
        isForeground: Bool = false,
        authorization: ExpenseReminderAuthorization = .authorized
    ) -> ExpenseReminderEvaluation {
        ExpenseReminderEvaluation(
            isEnabled: true,
            hasCompletedFirstUse: true,
            authorization: authorization,
            isForeground: isForeground,
            lastActiveAt: lastActive,
            now: now,
            hasPendingReminder: false,
            lastReminderDeliveredAt: nil
        )
    }
}

private struct TestSchedulingError: Error {}

@MainActor
private final class Environment {
    let clock: ControllableClock
    let store = InMemoryExpenseReminderStore()
    let center = FakeUserNotificationCenter()
    let analytics = RecordingAnalytics()
    let flags = ExpenseReminderTestFlags()
    let calendarBox: CalendarBox
    var calendar: Calendar {
        get { calendarBox.calendar }
        set { calendarBox.calendar = newValue }
    }
    var completedFirstUse: Bool {
        get { flags.completedFirstUse }
        set { flags.completedFirstUse = newValue }
    }
    var openedAddExpense: Int {
        get { flags.openedAddExpense }
        set { flags.openedAddExpense = newValue }
    }
    let scheduler: ExpenseReminderScheduler

    init(now: Date, policy: ExpenseReminderPolicy = .current) {
        calendarBox = CalendarBox(calendar: Self.utcCalendar())
        clock = ControllableClock(now: now)
        let flags = flags
        let calendarBox = calendarBox
        scheduler = ExpenseReminderScheduler(
            store: store,
            notifications: center,
            clock: clock,
            calendarProvider: { calendarBox.calendar },
            policy: policy,
            analytics: analytics,
            hasCompletedFirstUse: { flags.completedFirstUse },
            openAddExpense: { flags.openedAddExpense += 1 }
        )
    }

    func makeScheduler(policy: ExpenseReminderPolicy = .current) -> ExpenseReminderScheduler {
        ExpenseReminderScheduler(
            store: store,
            notifications: center,
            clock: clock,
            calendarProvider: { self.calendarBox.calendar },
            policy: policy,
            analytics: analytics,
            hasCompletedFirstUse: { self.flags.completedFirstUse },
            openAddExpense: { self.flags.openedAddExpense += 1 }
        )
    }

    static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let date = components.date else {
            preconditionFailure("Invalid test date")
        }
        return date
    }
}

private final class CalendarBox {
    var calendar: Calendar
    init(calendar: Calendar) {
        self.calendar = calendar
    }
}

private final class ExpenseReminderTestFlags {
    var completedFirstUse = true
    var openedAddExpense = 0
}

private final class InMemoryExpenseReminderStore: ExpenseReminderStoring {
    var isEnabled = true
    var lastActiveAt: Date?
    var lastScheduledReminderAt: Date?
    var lastReminderDeliveredAt: Date?
    var campaignVersion = 0
    var didAttemptProvisionalAuthorization = false
    var analyticsSignatures: [String: String] = [:]
    var conversionAttribution: ExpenseReminderConversionAttribution?
}

private final class FakeUserNotificationCenter: UserNotificationScheduling {
    var status: UNAuthorizationStatus = .authorized
    var requestedOptions: [UNAuthorizationOptions] = []
    var requestError: Error?
    var addError: Error?
    var failRemoval = false
    var pendingItems: [ScheduledNotificationSnapshot] = []
    var deliveredItems: [DeliveredNotificationSnapshot] = []

    var expenseReminder: ScheduledNotificationSnapshot? {
        pendingItems.first { $0.identifier == ExpenseReminderPolicy.current.notificationIdentifier }
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedOptions.append(options)
        if let requestError { throw requestError }
        status = options.contains(.provisional) ? .provisional : .authorized
        return true
    }

    func add(
        identifier: String,
        title: String,
        body: String,
        userInfoKind: String,
        fireDate: Date,
        calendar: Calendar
    ) async throws {
        if let addError { throw addError }
        pendingItems.removeAll { $0.identifier == identifier }
        pendingItems.append(
            ScheduledNotificationSnapshot(
                identifier: identifier,
                fireDate: fireDate,
                title: title,
                body: body,
                userInfoKind: userInfoKind
            )
        )
    }

    func pending() async -> [ScheduledNotificationSnapshot] { pendingItems }

    func removePending(withIdentifiers identifiers: [String]) async {
        guard !failRemoval else { return }
        pendingItems.removeAll { identifiers.contains($0.identifier) }
    }

    func delivered() async -> [DeliveredNotificationSnapshot] { deliveredItems }

    func removeDelivered(withIdentifiers identifiers: [String]) async {
        deliveredItems.removeAll { identifiers.contains($0.identifier) }
    }
}

private extension RecordingAnalytics {
    var scheduledCount: Int {
        count(AppAnalytics.Event.checkInScheduleResult, result: AppAnalytics.Outcome.success.rawValue)
    }
}
