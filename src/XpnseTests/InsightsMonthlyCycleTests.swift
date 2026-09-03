//
//  InsightsMonthlyCycleTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class InsightsMonthlyCycleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    func testFocusTransactionsDifferBetweenStartDay1And26() {
        let august15 = expense(year: 2026, month: 8, day: 15, amount: 50)
        let july30 = expense(year: 2026, month: 7, day: 30, amount: 20)
        let transactions = [august15, july30]
        let focus = date(2026, 8, 15, hour: 12)

        let calendarMonthSnapshot = InsightsAnalyticsEngine.build(
            transactions: transactions,
            recurringItems: [],
            discretionaryCategoryIds: [],
            focusDate: focus,
            calendar: calendar,
            cycleConfiguration: .calendarMonth
        )
        XCTAssertEqual(calendarMonthSnapshot.focusMonth, 8)
        XCTAssertEqual(calendarMonthSnapshot.months.first { $0.monthNumber == 8 }?.expense, 50)
        XCTAssertEqual(calendarMonthSnapshot.months.first { $0.monthNumber == 8 }?.month, "Aug")

        let customSnapshot = InsightsAnalyticsEngine.build(
            transactions: transactions,
            recurringItems: [],
            discretionaryCategoryIds: [],
            focusDate: focus,
            calendar: calendar,
            cycleConfiguration: .fixedStartDay(26)
        )
        XCTAssertEqual(customSnapshot.focusMonth, 7)
        XCTAssertEqual(customSnapshot.months.first { $0.monthNumber == 7 }?.expense, 70)
        XCTAssertEqual(customSnapshot.months.first { $0.monthNumber == 7 }?.month, "Jul–Aug")
        XCTAssertTrue(customSnapshot.focusMonthLabel.contains("26"))
        XCTAssertTrue(customSnapshot.focusMonthLabel.contains("25"))
    }

    func testExpenseTrendBuilderStartDay1BucketsByCalendarDay() {
        let now = date(2026, 8, 30)
        let spend = expense(year: 2026, month: 8, day: 10, amount: 40)
        let model = ExpenseTrendBuilder.build(
            expenses: [spend],
            year: 2026,
            calendar: calendar,
            now: now,
            configuration: .calendarMonth
        )

        XCTAssertEqual(model.projectedMonth, 8)
        XCTAssertTrue(model.actualPoints.contains { $0.month == 8 && $0.day == 10 && $0.dayAmount == 40 })
        XCTAssertTrue(model.projectedPoints.contains { $0.day == 31 })
        XCTAssertEqual(model.actualPoints.first { $0.month == 8 }?.monthLabel, "Aug")
        XCTAssertEqual(model.xAxisCalendarDays.first, 1)
        XCTAssertEqual(model.calendarDayLabel(forDayIndex: 10), 10)
    }

    func testExpenseTrendBuilderStartDay26UsesDayOfCycle() {
        let now = date(2026, 8, 30, hour: 12)
        let spend = expense(year: 2026, month: 8, day: 26, amount: 25)
        let model = ExpenseTrendBuilder.build(
            expenses: [spend],
            year: 2026,
            calendar: calendar,
            now: now,
            configuration: .fixedStartDay(26)
        )

        XCTAssertEqual(model.projectedMonth, 8)
        XCTAssertTrue(model.actualPoints.contains { $0.month == 8 && $0.day == 1 && $0.dayAmount == 25 })
        XCTAssertEqual(model.actualPoints.first { $0.month == 8 }?.monthLabel, "Aug–Sep")
        XCTAssertEqual(model.xAxisCalendarDays.first, 26)
        XCTAssertEqual(model.calendarDayLabel(forDayIndex: 1), 26)
        XCTAssertEqual(
            Array(model.xAxisCalendarDays.prefix(7)),
            [26, 27, 28, 29, 30, 31, 1]
        )
    }

    func testExpenseTrendIncludesDecemberCycleInEarlyJanuaryWhenStartDayIs26() {
        let now = date(2026, 1, 5, hour: 12)
        let configuration = MonthlyCycleConfiguration.fixedStartDay(26)
        let resolver = MonthlyCycleResolver(configuration: configuration, calendar: calendar)
        let current = resolver.currentCycle(for: now)
        XCTAssertEqual(current.startYear, 2025)
        XCTAssertEqual(current.startMonth, 12)

        let spend = expense(year: 2025, month: 12, day: 26, amount: 40)
        let model = ExpenseTrendBuilder.build(
            expenses: [spend],
            year: current.startYear,
            calendar: calendar,
            now: now,
            configuration: configuration
        )

        XCTAssertEqual(model.projectedMonth, 12)
        XCTAssertTrue(model.actualPoints.contains { $0.month == 12 && $0.day == 1 && $0.dayAmount == 40 })
        XCTAssertEqual(model.actualPoints.first { $0.month == 12 }?.monthLabel, "Dec–Jan")
        XCTAssertEqual(model.xAxisCalendarDays.first, 26)
    }

    func testChartSeriesLabelIsSingleMonthWhenStartDayIs1() {
        let resolver = MonthlyCycleResolver(configuration: .calendarMonth, calendar: calendar)
        let cycle = resolver.cycleStarting(year: 2026, month: 8)!
        XCTAssertEqual(
            MonthlyCycleFormatting.chartSeriesLabel(
                for: cycle,
                configuration: .calendarMonth,
                locale: Locale(identifier: "en_US_POSIX")
            ),
            "Aug"
        )
    }

    func testRevisionIncludesMonthlyCycleStartDay() {
        let revisionA = InsightsResultCache.revision(
            transactionUpdatedAtById: [:],
            recurringUpdatedAtById: [:],
            focusDay: date(2026, 8, 15),
            currencyCode: "INR",
            categorySpendingRevision: "roles",
            monthlyCycleStartDay: 1,
            calendar: calendar
        )
        let revisionB = InsightsResultCache.revision(
            transactionUpdatedAtById: [:],
            recurringUpdatedAtById: [:],
            focusDay: date(2026, 8, 15),
            currencyCode: "INR",
            categorySpendingRevision: "roles",
            monthlyCycleStartDay: 26,
            calendar: calendar
        )
        XCTAssertNotEqual(revisionA, revisionB)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func expense(year: Int, month: Int, day: Int, amount: Double) -> Transaction {
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        return Transaction(
            id: UUID().uuidString,
            type: .expense,
            categoryId: "other",
            amount: amount,
            date: date.timeIntervalSince1970,
            title: "Cycle",
            currency: CurrencyOption(id: 1, code: "INR", name: "Indian Rupee", symbol: "₹")
        )
    }
}
