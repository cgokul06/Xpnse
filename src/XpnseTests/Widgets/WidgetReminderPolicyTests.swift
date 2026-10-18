//
//  WidgetReminderPolicyTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class WidgetReminderPolicyTests: XCTestCase {
    private var directory: URL!
    private let production = WidgetReminderPolicy.production
    private let debugPolicy = WidgetReminderPolicy.debug

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-reminder-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        WidgetReminderActivityStore.fileURLOverride = directory.appendingPathComponent(WidgetReminderActivityStore.fileName)
    }

    override func tearDown() {
        WidgetReminderActivityStore.fileURLOverride = nil
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testMissingActivityStaysNormalAndDoesNotCreateAFile() {
        let now = date(2026, 6, 2, 12)
        XCTAssertEqual(state(.fresh, now: now), .normal)
        XCTAssertFalse(FileManager.default.fileExists(atPath: WidgetReminderActivityStore.fileURLOverride!.path))
        XCTAssertEqual(WidgetReminderActivityStore.load(), .fresh)
        XCTAssertFalse(FileManager.default.fileExists(atPath: WidgetReminderActivityStore.fileURLOverride!.path))
    }

    func testRepeatedReadsDoNotWrite() {
        WidgetReminderActivityStore.recordAppOpen(at: date(2026, 6, 1, 10), remindersEnabled: true)
        let first = try? Data(contentsOf: WidgetReminderActivityStore.fileURLOverride!)
        _ = WidgetReminderActivityStore.load()
        _ = WidgetReminderActivityStore.load()
        let second = try? Data(contentsOf: WidgetReminderActivityStore.fileURLOverride!)
        XCTAssertEqual(first, second)
    }

    func testActivityInsideADayStaysNormal() {
        let opened = date(2026, 6, 1, 10)
        let activity = WidgetReminderActivity(lastAppOpenAt: opened, lastExpenseSavedAt: nil, remindersEnabled: true)
        XCTAssertEqual(state(activity, now: opened.addingTimeInterval(23 * 60 * 60)), .normal)
    }

    func testTwentyFourToFortyEightHoursIsTheFirstVersion() {
        let opened = date(2026, 6, 1, 10)
        let activity = WidgetReminderActivity(lastAppOpenAt: opened, lastExpenseSavedAt: nil, remindersEnabled: true)
        XCTAssertEqual(state(activity, now: opened.addingTimeInterval(24 * 60 * 60)), .gentleReminder)
        XCTAssertEqual(state(activity, now: opened.addingTimeInterval(47 * 60 * 60)), .gentleReminder)
    }

    func testFortyEightHoursIsTheSecondVersion() {
        let opened = date(2026, 6, 1, 10)
        let activity = WidgetReminderActivity(lastAppOpenAt: opened, lastExpenseSavedAt: nil, remindersEnabled: true)
        XCTAssertEqual(state(activity, now: opened.addingTimeInterval(48 * 60 * 60)), .overdueReminder)
    }

    func testAppOpenOrExpenseSaveReturnsToNormal() {
        let opened = date(2026, 6, 1, 10)
        let laterOpen = date(2026, 6, 4, 9)
        var activity = WidgetReminderActivity(lastAppOpenAt: opened, lastExpenseSavedAt: nil, remindersEnabled: true)
        XCTAssertEqual(state(activity, now: date(2026, 6, 4, 10)), .overdueReminder)

        activity.lastAppOpenAt = laterOpen
        XCTAssertEqual(state(activity, now: laterOpen.addingTimeInterval(60)), .normal)

        activity.lastExpenseSavedAt = date(2026, 6, 4, 12)
        XCTAssertEqual(state(activity, now: date(2026, 6, 4, 12, 5)), .normal)
    }

    func testDisabledRemindersStayNormal() {
        let activity = WidgetReminderActivity(
            lastAppOpenAt: date(2026, 6, 1, 10),
            lastExpenseSavedAt: nil,
            remindersEnabled: false
        )
        XCTAssertEqual(state(activity, now: date(2026, 6, 6, 10)), .normal)
    }

    func testSameCalendarDayStaysNormalAcrossALongDaylightSavingDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let opened = date(2026, 11, 1, 0, 30, calendar: calendar)
        let stillSameDay = date(2026, 11, 1, 23, 45, calendar: calendar)
        let activity = WidgetReminderActivity(lastAppOpenAt: opened, lastExpenseSavedAt: nil, remindersEnabled: true)

        XCTAssertEqual(
            WidgetReminderEvaluator.state(activity: activity, now: stillSameDay, policy: production, calendar: calendar),
            .normal
        )
        XCTAssertGreaterThan(stillSameDay.timeIntervalSince(opened), 24 * 60 * 60)
    }

    func testDebugVersionsAppearAtThirtyAndSixtyMinutes() {
        let opened = date(2026, 6, 1, 10)
        let activity = WidgetReminderActivity(lastAppOpenAt: opened, lastExpenseSavedAt: nil, remindersEnabled: true)
        XCTAssertEqual(state(activity, now: opened.addingTimeInterval(29 * 60), policy: debugPolicy), .normal)
        XCTAssertEqual(state(activity, now: opened.addingTimeInterval(30 * 60), policy: debugPolicy), .gentleReminder)
        XCTAssertEqual(state(activity, now: opened.addingTimeInterval(59 * 60), policy: debugPolicy), .gentleReminder)
        XCTAssertEqual(state(activity, now: opened.addingTimeInterval(60 * 60), policy: debugPolicy), .overdueReminder)
        #if DEBUG
        XCTAssertEqual(WidgetReminderPolicy.runtime, debugPolicy)
        #endif
    }

    func testTimelineTransitionsStayInTheFutureAndDoNotWrite() {
        let opened = date(2026, 6, 1, 10)
        let now = opened.addingTimeInterval(60)
        let activity = WidgetReminderActivity(lastAppOpenAt: opened, lastExpenseSavedAt: nil, remindersEnabled: true)
        let dates = WidgetReminderEvaluator.transitionDates(
            activity: activity,
            now: now,
            policy: production,
            calendar: utcCalendar()
        )

        XCTAssertEqual(dates, [
            opened.addingTimeInterval(24 * 60 * 60),
            opened.addingTimeInterval(48 * 60 * 60)
        ])
        XCTAssertTrue(dates.allSatisfy { $0 > now })
        XCTAssertFalse(FileManager.default.fileExists(atPath: WidgetReminderActivityStore.fileURLOverride!.path))
    }

    func testDebugTimelineUsesHalfHourAndOneHour() {
        let opened = date(2026, 6, 1, 10)
        let activity = WidgetReminderActivity(lastAppOpenAt: opened, lastExpenseSavedAt: nil, remindersEnabled: true)
        let dates = WidgetReminderEvaluator.transitionDates(
            activity: activity,
            now: opened,
            policy: debugPolicy,
            calendar: utcCalendar()
        )
        XCTAssertEqual(dates, [
            opened.addingTimeInterval(30 * 60),
            opened.addingTimeInterval(60 * 60)
        ])
    }

    func testExpenseTimestampIsUnchangedUntilASuccessfulSaveIsRecorded() {
        let opened = date(2026, 6, 1, 10)
        WidgetReminderActivityStore.recordAppOpen(at: opened, remindersEnabled: true)
        XCTAssertNil(WidgetReminderActivityStore.load().lastExpenseSavedAt)

        let saved = date(2026, 6, 1, 11)
        WidgetReminderActivityStore.recordExpenseSaved(at: saved)
        XCTAssertEqual(WidgetReminderActivityStore.load().lastExpenseSavedAt, saved)
        XCTAssertEqual(WidgetReminderActivityStore.load().lastAppOpenAt, opened)
    }

    func testBothFamiliesShareOneActivityDecision() {
        let opened = date(2026, 6, 1, 10)
        let activity = WidgetReminderActivity(lastAppOpenAt: opened, lastExpenseSavedAt: nil, remindersEnabled: true)
        let now = opened.addingTimeInterval(30 * 60 * 60)
        let decision = state(activity, now: now)
        XCTAssertEqual(decision, .gentleReminder)
        XCTAssertEqual(
            WidgetReminderLink.addExpenseURL(family: "systemSmall").absoluteString,
            "snapledger://add-transaction?family=systemSmall"
        )
        XCTAssertEqual(
            WidgetReminderLink.addExpenseURL(family: "systemMedium").absoluteString,
            "snapledger://add-transaction?family=systemMedium"
        )
    }

    private func state(
        _ activity: WidgetReminderActivity,
        now: Date,
        policy: WidgetReminderPolicy = .production
    ) -> WidgetReminderState {
        WidgetReminderEvaluator.state(activity: activity, now: now, policy: policy, calendar: utcCalendar())
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int = 0,
        calendar: Calendar? = nil
    ) -> Date {
        let calendar = calendar ?? utcCalendar()
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date!
    }
}
