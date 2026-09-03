//
//  RecurringStartOfDayRegressionTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class RecurringStartOfDayRegressionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testUpcomingHidesMaterializedStartOfDayOccurrence() {
        let today = date(2026, 9, 3)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let periodEnd = calendar.date(byAdding: .day, value: 7, to: today)!
        let rule = RecurringTransaction(
            id: UUID(),
            title: "Rent",
            merchant: nil,
            type: TransactionType.expense.rawValue,
            categoryIdentifier: nil,
            amount: 100,
            startDate: today,
            endDate: nil,
            recurrence: .daily,
            nextOccurrence: tomorrow,
            lastTransactionAddedOn: today,
            state: .active,
            metadata: nil
        )
        let todayKey = UpcomingRecurringProjector.materializationKey(
            seriesId: rule.id.uuidString,
            occurrenceEpoch: today.timeIntervalSince1970
        )

        let projected = UpcomingRecurringProjector.project(
            rules: [rule],
            periodStart: today,
            periodEnd: periodEnd,
            today: today,
            calendar: calendar,
            materializedKeys: [todayKey]
        )

        XCTAssertFalse(projected.contains { calendar.isDate($0.occurrenceDate, inSameDayAs: today) })
        XCTAssertTrue(projected.contains { calendar.isDate($0.occurrenceDate, inSameDayAs: tomorrow) })
    }

    func testReminderFireDateUnchangedWhenOccurrenceIsStartOfDay() {
        let today = date(2026, 9, 3)
        let afternoon = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: today)!
        let previousEvening = calendar.date(
            byAdding: .hour,
            value: 21,
            to: calendar.date(byAdding: .day, value: -1, to: today)!
        )!

        let offset = RecurringReminderScheduleMath.offsetFromEndOfTransactionDay(
            transactionDay: afternoon,
            reminderDateTime: previousEvening,
            calendar: calendar
        )
        let fireFromAfternoon = RecurringReminderScheduleMath.fireDateForOccurrence(
            occurrenceDay: afternoon,
            offsetFromEndOfTransactionDay: offset,
            calendar: calendar
        )
        let fireFromStartOfDay = RecurringReminderScheduleMath.fireDateForOccurrence(
            occurrenceDay: today,
            offsetFromEndOfTransactionDay: offset,
            calendar: calendar
        )

        XCTAssertEqual(fireFromAfternoon, fireFromStartOfDay)
        XCTAssertEqual(calendar.startOfDay(for: fireFromStartOfDay), calendar.date(byAdding: .day, value: -1, to: today))
    }

    func testEndedSeriesStayInactive() {
        let ended = RecurringTransaction(
            id: UUID(),
            title: "Rent",
            merchant: nil,
            type: TransactionType.expense.rawValue,
            categoryIdentifier: nil,
            amount: 100,
            startDate: date(2026, 8, 1),
            endDate: date(2026, 8, 15),
            recurrence: .daily,
            nextOccurrence: nil,
            lastTransactionAddedOn: date(2026, 8, 15),
            state: .inactive,
            metadata: nil
        )

        XCTAssertEqual(ended.state, .inactive)
        XCTAssertNil(ended.nextOccurrence)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
