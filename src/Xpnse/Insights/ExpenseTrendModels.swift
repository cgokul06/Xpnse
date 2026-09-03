//
//  ExpenseTrendModels.swift
//  Xpnse
//

import SwiftUI

struct ExpenseTrendPoint: Identifiable, Equatable, Codable, Sendable {
    var id: String { "\(month)-\(day)-\(isProjected ? "p" : "a")" }
    let day: Int
    let month: Int
    let monthLabel: String
    let cumulativeAmount: Double
    /// Spend recorded on this calendar day (0 when none). Used for chart markers.
    let dayAmount: Double
    let isProjected: Bool
}

struct ExpenseTrendChartModel: Equatable, Codable, Sendable {
    let points: [ExpenseTrendPoint]
    let year: Int
    let projectedMonth: Int?
    let hasProjection: Bool
    /// Calendar day-of-month for each cycle-day index (`xAxisCalendarDays[0]` = day index 1).
    let xAxisCalendarDays: [Int]

    init(
        points: [ExpenseTrendPoint],
        year: Int,
        projectedMonth: Int?,
        hasProjection: Bool,
        xAxisCalendarDays: [Int] = Array(1...31)
    ) {
        self.points = points
        self.year = year
        self.projectedMonth = projectedMonth
        self.hasProjection = hasProjection
        self.xAxisCalendarDays = xAxisCalendarDays
    }

    func calendarDayLabel(forDayIndex day: Int) -> Int? {
        let index = day - 1
        guard xAxisCalendarDays.indices.contains(index) else { return nil }
        return xAxisCalendarDays[index]
    }

    var monthsInChart: [Int] {
        Array(Set(points.map(\.month))).sorted()
    }

    var actualPoints: [ExpenseTrendPoint] {
        points.filter { !$0.isProjected }
    }

    var projectedPoints: [ExpenseTrendPoint] {
        points.filter(\.isProjected)
    }

    /// Days with a real expense — used for chart dots.
    var actualExpenseMarkers: [ExpenseTrendPoint] {
        actualPoints.filter { $0.dayAmount > 0.01 }
    }
}

enum ExpenseTrendMonthPalette {
    static let colors: [Color] = [
        Color(red: 0.91, green: 0.30, blue: 0.24), // Jan
        Color(red: 0.90, green: 0.49, blue: 0.13), // Feb
        Color(red: 0.95, green: 0.77, blue: 0.06), // Mar
        Color(red: 0.15, green: 0.68, blue: 0.38), // Apr
        Color(red: 0.10, green: 0.74, blue: 0.61), // May
        Color(red: 0.20, green: 0.60, blue: 0.86), // Jun
        Color(red: 0.20, green: 0.29, blue: 0.80), // Jul
        Color(red: 0.56, green: 0.27, blue: 0.68), // Aug
        Color(red: 0.83, green: 0.33, blue: 0.60), // Sep
        Color(red: 0.50, green: 0.55, blue: 0.55), // Oct
        Color(red: 0.17, green: 0.24, blue: 0.31), // Nov
        Color(red: 0.75, green: 0.22, blue: 0.17)  // Dec
    ]

    static func color(forMonth month: Int) -> Color {
        guard (1...12).contains(month) else { return colors[0] }
        return colors[month - 1]
    }

    static func shortLabel(forMonth month: Int, calendar: Calendar = .current) -> String {
        guard (1...12).contains(month) else { return "" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        let symbols = formatter.shortMonthSymbols ?? []
        guard month - 1 < symbols.count else { return "\(month)" }
        return symbols[month - 1]
    }
}

enum ExpenseTrendBuilder {
    static func build(
        expenses: [Transaction],
        year: Int,
        recurringItems: [RecurringTransaction] = [],
        calendar: Calendar = .current,
        now: Date = Date(),
        configuration: MonthlyCycleConfiguration = .calendarMonth
    ) -> ExpenseTrendChartModel {
        let resolver = MonthlyCycleResolver(configuration: configuration, calendar: calendar)
        let currentCycle = resolver.currentCycle(for: now)
        let currentYear = currentCycle.startYear
        let currentMonth = currentCycle.startMonth
        let currentDay = currentCycle.dayIndex(of: now) ?? 1

        var dailyTotals: [Int: [Int: Double]] = [:]

        for transaction in expenses where transaction.type == .expense {
            let date = Date(timeIntervalSince1970: transaction.date)
            let cycle = resolver.cycleContaining(date)
            guard cycle.startYear == year,
                  let day = cycle.dayIndex(of: date)
            else { continue }

            dailyTotals[cycle.startMonth, default: [:]][day, default: 0] += transaction.totalAmount
        }

        var points: [ExpenseTrendPoint] = []
        var projectedMonth: Int?

        for month in 1...12 {
            guard let cycle = resolver.cycleStarting(year: year, month: month) else { continue }
            let isCurrentMonth = year == currentYear && month == currentMonth
            let monthDaily = dailyTotals[month] ?? [:]

            if year == currentYear, month > currentMonth { continue }
            if !isCurrentMonth, monthDaily.isEmpty { continue }

            let actualLastDay: Int
            if isCurrentMonth {
                actualLastDay = currentDay
            } else {
                actualLastDay = cycle.lengthInDays
            }

            guard actualLastDay > 0 else { continue }

            var cumulative: Double = 0
            let label = MonthlyCycleFormatting.chartSeriesLabel(
                for: cycle,
                configuration: configuration,
                locale: calendar.locale ?? .current
            )

            for day in 1...actualLastDay {
                let daySpend = monthDaily[day] ?? 0
                cumulative += daySpend
                points.append(
                    ExpenseTrendPoint(
                        day: day,
                        month: month,
                        monthLabel: label,
                        cumulativeAmount: cumulative,
                        dayAmount: daySpend,
                        isProjected: false
                    )
                )
            }

            guard isCurrentMonth else { continue }

            let extrapolation = MonthExpenseExtrapolationEngine.extrapolateRemainingDays(
                cycle: cycle,
                asOfDate: now,
                historicalExpenses: expenses,
                recurringItems: recurringItems,
                resolver: resolver,
                calendar: calendar
            )

            guard extrapolation.hasProjection else {
                if monthDaily.isEmpty {
                    points.removeAll { $0.month == month }
                }
                continue
            }

            // Anchor projection at today so the dotted segment continues the solid line.
            points.append(
                ExpenseTrendPoint(
                    day: currentDay,
                    month: month,
                    monthLabel: label,
                    cumulativeAmount: cumulative,
                    dayAmount: 0,
                    isProjected: true
                )
            )

            for dayAmount in extrapolation.dailyAmounts {
                cumulative += dayAmount.total
                points.append(
                    ExpenseTrendPoint(
                        day: dayAmount.day,
                        month: month,
                        monthLabel: label,
                        cumulativeAmount: cumulative,
                        dayAmount: dayAmount.total,
                        isProjected: true
                    )
                )
            }
            projectedMonth = month
        }

        return ExpenseTrendChartModel(
            points: points,
            year: year,
            projectedMonth: projectedMonth,
            hasProjection: projectedMonth != nil,
            xAxisCalendarDays: calendarDayLabels(
                for: referenceCycle(year: year, currentYear: currentYear, currentCycle: currentCycle, resolver: resolver)
            )
        )
    }

    private static func referenceCycle(
        year: Int,
        currentYear: Int,
        currentCycle: BillingCycle,
        resolver: MonthlyCycleResolver
    ) -> BillingCycle {
        if year == currentYear {
            return currentCycle
        }
        return resolver.cycleStarting(year: year, month: 12) ?? currentCycle
    }

    /// Calendar day-of-month for cycle-day indexes 1...length. Ticks past the cycle are omitted.
    static func calendarDayLabels(for cycle: BillingCycle, xMax: Int = 31) -> [Int] {
        let lastIndex = min(xMax, cycle.lengthInDays)
        guard lastIndex >= 1 else { return Array(1...xMax) }
        return (1...lastIndex).compactMap { index in
            guard let date = cycle.dateForDayIndex(index) else { return nil }
            return cycle.calendar.component(.day, from: date)
        }
    }
}
