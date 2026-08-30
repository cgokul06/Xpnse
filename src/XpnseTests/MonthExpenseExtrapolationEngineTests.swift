//
//  MonthExpenseExtrapolationEngineTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class MonthExpenseExtrapolationEngineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// Regression: Aug 30 extrapolates day 31; June has only 30 days, so `31...30` used to trap.
    func testExtrapolateRemainingDaysDoesNotTrapWhenLookbackMonthIsShorter() {
        let result = MonthExpenseExtrapolationEngine.extrapolateRemainingDays(
            year: 2026,
            month: 8,
            asOfDay: 30,
            historicalExpenses: [],
            recurringItems: [],
            calendar: calendar
        )

        XCTAssertEqual(result.dailyAmounts.map(\.day), [31])
        XCTAssertEqual(result.dailyAmounts.first?.variableAmount, 0)
    }

    func testAverageVariableSkipsLookbackMonthsThatLackTheTargetDay() {
        let july31 = expense(year: 2026, month: 7, day: 31, amount: 100)
        let averages = MonthExpenseExtrapolationEngine.averageVariableAmountsByDay(
            historicalExpenses: [july31],
            targetYear: 2026,
            targetMonth: 8,
            fromDay: 31,
            throughDay: 31,
            lookbackMonths: 3,
            calendar: calendar
        )

        // June (30 days) is skipped; May and July still contribute (July 100, May 0).
        XCTAssertEqual(averages[31], 50)
    }

    func testAverageVariableDoesNotTrapForMarchLookingBackAtFebruary() {
        let averages = MonthExpenseExtrapolationEngine.averageVariableAmountsByDay(
            historicalExpenses: [],
            targetYear: 2026,
            targetMonth: 3,
            fromDay: 29,
            throughDay: 31,
            lookbackMonths: 3,
            calendar: calendar
        )

        XCTAssertEqual(averages[29], 0)
        XCTAssertEqual(averages[30], 0)
        XCTAssertEqual(averages[31], 0)
    }

    func testExpenseTrendBuilderDoesNotTrapOnAugust30() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 30))!
        let model = ExpenseTrendBuilder.build(
            expenses: [],
            year: 2026,
            calendar: calendar,
            now: now
        )

        XCTAssertTrue(model.hasProjection)
        XCTAssertEqual(model.projectedMonth, 8)
        XCTAssertTrue(model.projectedPoints.contains { $0.day == 31 })
    }

    private func expense(year: Int, month: Int, day: Int, amount: Double) -> Transaction {
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        return Transaction(
            id: UUID().uuidString,
            type: .expense,
            categoryId: "other",
            amount: amount,
            date: date.timeIntervalSince1970,
            title: "Lookback",
            currency: CurrencyOption(id: 1, code: "INR", name: "Indian Rupee", symbol: "₹")
        )
    }
}
