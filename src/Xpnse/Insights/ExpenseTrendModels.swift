//
//  ExpenseTrendModels.swift
//  Xpnse
//

import SwiftUI

struct ExpenseTrendPoint: Identifiable, Equatable {
    var id: String { "\(month)-\(day)-\(isProjected ? "p" : "a")" }
    let day: Int
    let month: Int
    let monthLabel: String
    let cumulativeAmount: Double
    let isProjected: Bool
}

struct ExpenseTrendChartModel: Equatable {
    let points: [ExpenseTrendPoint]
    let year: Int
    let projectedMonth: Int?
    let hasProjection: Bool

    var monthsInChart: [Int] {
        Array(Set(points.map(\.month))).sorted()
    }

    var actualPoints: [ExpenseTrendPoint] {
        points.filter { !$0.isProjected }
    }

    var projectedPoints: [ExpenseTrendPoint] {
        points.filter(\.isProjected)
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
        now: Date = Date()
    ) -> ExpenseTrendChartModel {
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        let currentYear = todayComponents.year ?? year
        let currentMonth = todayComponents.month ?? 1
        let currentDay = todayComponents.day ?? 1

        var dailyTotals: [Int: [Int: Double]] = [:]

        for transaction in expenses where transaction.type == .expense {
            let date = Date(timeIntervalSince1970: transaction.date)
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard components.year == year,
                  let month = components.month,
                  let day = components.day
            else { continue }

            dailyTotals[month, default: [:]][day, default: 0] += transaction.totalAmount
        }

        var points: [ExpenseTrendPoint] = []
        var projectedMonth: Int?

        for month in 1...12 {
            let isCurrentMonth = year == currentYear && month == currentMonth
            let monthDaily = dailyTotals[month] ?? [:]

            if year == currentYear, month > currentMonth { continue }
            if !isCurrentMonth, monthDaily.isEmpty { continue }

            let actualLastDay: Int
            if isCurrentMonth {
                actualLastDay = currentDay
            } else {
                actualLastDay = MonthExpenseExtrapolationEngine.daysInMonth(
                    month: month,
                    year: year,
                    calendar: calendar
                )
            }

            guard actualLastDay > 0 else { continue }

            var cumulative: Double = 0
            let label = ExpenseTrendMonthPalette.shortLabel(forMonth: month, calendar: calendar)

            for day in 1...actualLastDay {
                cumulative += monthDaily[day] ?? 0
                points.append(
                    ExpenseTrendPoint(
                        day: day,
                        month: month,
                        monthLabel: label,
                        cumulativeAmount: cumulative,
                        isProjected: false
                    )
                )
            }

            guard isCurrentMonth else { continue }

            let extrapolation = MonthExpenseExtrapolationEngine.extrapolateRemainingDays(
                year: year,
                month: month,
                asOfDay: currentDay,
                historicalExpenses: expenses,
                recurringItems: recurringItems,
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
            hasProjection: projectedMonth != nil
        )
    }
}
