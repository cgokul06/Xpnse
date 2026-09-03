//
//  MonthlyCycleResolverTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class MonthlyCycleResolverTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    // MARK: - Start day 1 (calendar month)

    func testStartDay1ProducesCalendarMonths() {
        let resolver = resolver(startDay: 1)

        assertCycle(
            resolver.cycleContaining(date(2026, 1, 15)),
            start: date(2026, 1, 1),
            end: date(2026, 1, 31)
        )
        assertCycle(
            resolver.cycleContaining(date(2026, 2, 1)),
            start: date(2026, 2, 1),
            end: date(2026, 2, 28)
        )
        assertCycle(
            resolver.cycleContaining(date(2026, 3, 31)),
            start: date(2026, 3, 1),
            end: date(2026, 3, 31)
        )
    }

    func testStartDay1MatchesPeriodDateRangeCalculator() {
        let configuration = MonthlyCycleConfiguration.calendarMonth
        let reference = date(2026, 8, 15, hour: 12)

        for offset in -3...3 {
            let range = PeriodDateRangeCalculator.dateRange(
                forOffset: offset,
                comparison: .monthly,
                calendar: calendar,
                referenceDate: reference,
                configuration: configuration
            )
            let cycle = resolver(startDay: 1).cycle(offset: offset, from: reference)
            XCTAssertEqual(range.start, cycle.start, "offset \(offset) start")
            XCTAssertEqual(range.end, cycle.inclusiveFetchEnd, "offset \(offset) end")
        }
    }

    // MARK: - Start day 10

    func testStartDay10SpansAdjacentMonths() {
        let resolver = resolver(startDay: 10)
        assertCycle(
            resolver.cycleContaining(date(2026, 1, 10)),
            start: date(2026, 1, 10),
            end: date(2026, 2, 9)
        )
        assertCycle(
            resolver.cycleContaining(date(2026, 2, 10)),
            start: date(2026, 2, 10),
            end: date(2026, 3, 9)
        )
        assertCycle(
            resolver.cycleContaining(date(2026, 3, 10)),
            start: date(2026, 3, 10),
            end: date(2026, 4, 9)
        )
        assertCycle(
            resolver.cycleContaining(date(2026, 1, 9)),
            start: date(2025, 12, 10),
            end: date(2026, 1, 9)
        )
    }

    // MARK: - Start day 26

    func testStartDay26Examples() {
        let resolver = resolver(startDay: 26)
        assertCycle(
            resolver.cycleContaining(date(2026, 7, 26)),
            start: date(2026, 7, 26),
            end: date(2026, 8, 25)
        )
        assertCycle(
            resolver.cycleContaining(date(2026, 8, 26)),
            start: date(2026, 8, 26),
            end: date(2026, 9, 25)
        )
        assertCycle(
            resolver.cycleContaining(date(2026, 9, 26)),
            start: date(2026, 9, 26),
            end: date(2026, 10, 25)
        )
    }

    // MARK: - Start day 30 clamping

    func testStartDay30NonLeapFebruary() {
        let resolver = resolver(startDay: 30)
        assertCycle(
            resolver.cycleContaining(date(2026, 1, 30)),
            start: date(2026, 1, 30),
            end: date(2026, 2, 27)
        )
        assertCycle(
            resolver.cycleContaining(date(2026, 2, 28)),
            start: date(2026, 2, 28),
            end: date(2026, 3, 29)
        )
        assertCycle(
            resolver.cycleContaining(date(2026, 3, 30)),
            start: date(2026, 3, 30),
            end: date(2026, 4, 29)
        )
    }

    func testStartDay30LeapFebruary() {
        let resolver = resolver(startDay: 30)
        assertCycle(
            resolver.cycleContaining(date(2024, 1, 30)),
            start: date(2024, 1, 30),
            end: date(2024, 2, 28)
        )
        assertCycle(
            resolver.cycleContaining(date(2024, 2, 29)),
            start: date(2024, 2, 29),
            end: date(2024, 3, 29)
        )
    }

    func testNextCycleDoesNotCarryClampedFebruaryDay() {
        let resolver = resolver(startDay: 30)
        let february = resolver.cycleContaining(date(2026, 2, 28))
        let march = resolver.nextCycle(from: february)
        assertCycle(march, start: date(2026, 3, 30), end: date(2026, 4, 29))
    }

    // MARK: - All start days / month lengths

    func testEveryStartDayClampsToEachMonthLength() {
        for startDay in MonthlyCycleConfiguration.allowedStartDays {
            let resolver = resolver(startDay: startDay)
            for month in 1...12 {
                guard let cycle = resolver.cycleStarting(year: 2026, month: month) else {
                    XCTFail("Missing cycle for startDay \(startDay) month \(month)")
                    continue
                }
                let daysInMonth = MonthExpenseExtrapolationEngine.daysInMonth(
                    month: month,
                    year: 2026,
                    calendar: calendar
                )
                XCTAssertEqual(
                    calendar.component(.day, from: cycle.start),
                    min(startDay, daysInMonth),
                    "startDay \(startDay) month \(month)"
                )
                XCTAssertEqual(
                    calendar.startOfDay(for: cycle.endDate),
                    calendar.date(byAdding: .day, value: -1, to: cycle.nextStart)
                )
            }
        }
    }

    func testLeapVersusNonLeapFebruaryStartDay30() {
        let resolver = resolver(startDay: 30)
        XCTAssertEqual(
            calendar.component(.day, from: resolver.cycleStarting(year: 2026, month: 2)!.start),
            28
        )
        XCTAssertEqual(
            calendar.component(.day, from: resolver.cycleStarting(year: 2024, month: 2)!.start),
            29
        )
    }

    // MARK: - Year rollover

    func testDecemberToJanuaryRollover() {
        let resolver = resolver(startDay: 26)
        let cycle = resolver.cycleContaining(date(2026, 12, 26))
        assertCycle(cycle, start: date(2026, 12, 26), end: date(2027, 1, 25))
        let next = resolver.nextCycle(from: cycle)
        assertCycle(next, start: date(2027, 1, 26), end: date(2027, 2, 25))
    }

    // MARK: - Containing / previous / next / offset

    func testCycleContainingBeforeOnAndAfterStart() {
        let resolver = resolver(startDay: 26)
        assertCycle(
            resolver.cycleContaining(date(2026, 8, 25)),
            start: date(2026, 7, 26),
            end: date(2026, 8, 25)
        )
        assertCycle(
            resolver.cycleContaining(date(2026, 8, 26)),
            start: date(2026, 8, 26),
            end: date(2026, 9, 25)
        )
        assertCycle(
            resolver.cycleContaining(date(2026, 8, 27)),
            start: date(2026, 8, 26),
            end: date(2026, 9, 25)
        )
    }

    func testPreviousAndNextCycle() {
        let resolver = resolver(startDay: 10)
        let current = resolver.cycleContaining(date(2026, 8, 15))
        let previous = resolver.previousCycle(from: current)
        let next = resolver.nextCycle(from: current)
        assertCycle(current, start: date(2026, 8, 10), end: date(2026, 9, 9))
        assertCycle(previous, start: date(2026, 7, 10), end: date(2026, 8, 9))
        assertCycle(next, start: date(2026, 9, 10), end: date(2026, 10, 9))
        XCTAssertEqual(next.start, current.nextStart)
    }

    func testCurrentCycleAndOffset() {
        let resolver = resolver(startDay: 26)
        let reference = date(2026, 8, 15, hour: 12)
        let current = resolver.currentCycle(for: reference)
        assertCycle(current, start: date(2026, 7, 26), end: date(2026, 8, 25))

        XCTAssertEqual(resolver.cycle(offset: 0, from: reference).start, current.start)
        XCTAssertEqual(
            resolver.cycle(offset: -1, from: reference).start,
            date(2026, 6, 26)
        )
        XCTAssertEqual(
            resolver.cycle(offset: 1, from: reference).start,
            date(2026, 8, 26)
        )
        XCTAssertEqual(
            resolver.cycle(offset: 2, from: reference).start,
            date(2026, 9, 26)
        )
    }

    // MARK: - Interval membership

    func testContainsUsesHalfOpenInterval() {
        let resolver = resolver(startDay: 26)
        let cycle = resolver.cycleContaining(date(2026, 8, 26))
        XCTAssertTrue(cycle.contains(date(2026, 8, 26)))
        XCTAssertTrue(cycle.contains(date(2026, 9, 25, hour: 23, minute: 59, second: 59)))
        XCTAssertFalse(cycle.contains(date(2026, 8, 26).addingTimeInterval(-1)))
        XCTAssertFalse(cycle.contains(date(2026, 9, 26)))
        XCTAssertEqual(cycle.inclusiveFetchEnd, cycle.nextStart.addingTimeInterval(-1))
        XCTAssertTrue(cycle.contains(cycle.inclusiveFetchEnd))
    }

    func testTransactionOnCycleStartBelongsToNewCycle() {
        let resolver = resolver(startDay: 10)
        let start = date(2026, 8, 10)
        let previous = resolver.cycleContaining(date(2026, 8, 9))
        let current = resolver.cycleContaining(start)
        XCTAssertFalse(previous.contains(start))
        XCTAssertTrue(current.contains(start))
    }

    func testTransactionOnCycleEndBelongsToCurrentCycle() {
        let resolver = resolver(startDay: 10)
        let endOfDay = date(2026, 9, 9, hour: 23, minute: 59, second: 59)
        let current = resolver.cycleContaining(date(2026, 8, 10))
        let next = resolver.nextCycle(from: current)
        XCTAssertTrue(current.contains(endOfDay))
        XCTAssertFalse(next.contains(endOfDay))
    }

    // MARK: - Helpers

    private func resolver(startDay: Int) -> MonthlyCycleResolver {
        MonthlyCycleResolver(
            configuration: .fixedStartDay(startDay),
            calendar: calendar
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        )!
    }

    private func assertCycle(
        _ cycle: BillingCycle,
        start: Date,
        end: Date,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            calendar.startOfDay(for: cycle.start),
            calendar.startOfDay(for: start),
            "start",
            file: file,
            line: line
        )
        XCTAssertEqual(
            calendar.startOfDay(for: cycle.endDate),
            calendar.startOfDay(for: end),
            "endDate",
            file: file,
            line: line
        )
        XCTAssertEqual(
            cycle.nextStart,
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)),
            "nextStart",
            file: file,
            line: line
        )
    }
}
