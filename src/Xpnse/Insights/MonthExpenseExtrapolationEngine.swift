//
//  MonthExpenseExtrapolationEngine.swift
//  Xpnse
//

import Foundation

/// Per-day breakdown of an extrapolated expense amount.
struct DayExtrapolationAmount: Equatable, Sendable {
    let day: Int
    /// Recurring expenses scheduled for this day (not yet realized).
    let fixedAmount: Double
    /// Average non-recurring spend on this calendar day across lookback months.
    let variableAmount: Double

    var total: Double { fixedAmount + variableAmount }
}

/// Result of extrapolating remaining days in a month.
struct MonthExpenseExtrapolationResult: Equatable, Sendable {
    let year: Int
    let month: Int
    /// Last day with actual data (typically today).
    let asOfDay: Int
    let dailyAmounts: [DayExtrapolationAmount]

    var hasProjection: Bool { !dailyAmounts.isEmpty }
}

/// Reusable month expense extrapolation:
/// - Fixed: active recurring expense occurrences scheduled for remaining days
/// - Variable: average of non-recurring expenses on those day-of-month values
///   across up to `lookbackMonths` prior months
///
/// Recurring-generated historical transactions are excluded from the variable
/// average so scheduled recurring is not counted twice.
enum MonthExpenseExtrapolationEngine {
    static let defaultLookbackMonths = 3

    static func extrapolateRemainingDays(
        year: Int,
        month: Int,
        asOfDay: Int,
        historicalExpenses: [Transaction],
        recurringItems: [RecurringTransaction],
        lookbackMonths: Int = defaultLookbackMonths,
        calendar: Calendar = .current
    ) -> MonthExpenseExtrapolationResult {
        let lastDay = daysInMonth(month: month, year: year, calendar: calendar)
        guard asOfDay < lastDay else {
            return MonthExpenseExtrapolationResult(
                year: year,
                month: month,
                asOfDay: asOfDay,
                dailyAmounts: []
            )
        }

        let fixedByDay = scheduledRecurringAmountsByDay(
            recurringItems: recurringItems,
            year: year,
            month: month,
            fromDay: asOfDay + 1,
            throughDay: lastDay,
            calendar: calendar
        )

        let variableByDay = averageVariableAmountsByDay(
            historicalExpenses: historicalExpenses,
            targetYear: year,
            targetMonth: month,
            fromDay: asOfDay + 1,
            throughDay: lastDay,
            lookbackMonths: lookbackMonths,
            calendar: calendar
        )

        let dailyAmounts = (asOfDay + 1...lastDay).map { day in
            DayExtrapolationAmount(
                day: day,
                fixedAmount: fixedByDay[day] ?? 0,
                variableAmount: variableByDay[day] ?? 0
            )
        }

        return MonthExpenseExtrapolationResult(
            year: year,
            month: month,
            asOfDay: asOfDay,
            dailyAmounts: dailyAmounts
        )
    }

    // MARK: - Fixed (recurring schedule)

    static func scheduledRecurringAmountsByDay(
        recurringItems: [RecurringTransaction],
        year: Int,
        month: Int,
        fromDay: Int,
        throughDay: Int,
        calendar: Calendar = .current
    ) -> [Int: Double] {
        guard fromDay <= throughDay,
              let rangeStart = calendar.date(
                from: DateComponents(year: year, month: month, day: fromDay)
              ),
              let rangeEnd = calendar.date(
                from: DateComponents(year: year, month: month, day: throughDay, hour: 23, minute: 59, second: 59)
              )
        else { return [:] }

        var totals: [Int: Double] = [:]

        for item in recurringItems {
            guard item.state == .active,
                  item.type == TransactionType.expense.rawValue
            else { continue }

            let amount = NSDecimalNumber(decimal: item.amount).doubleValue
            guard amount > 0 else { continue }

            var occurrence = item.recurrence.firstOccurrence(
                onOrAfter: max(rangeStart, calendar.startOfDay(for: item.startDate)),
                calendar: calendar
            )

            var safety = 0
            while let current = occurrence, safety < 64 {
                safety += 1
                if let endDate = item.endDate, current > endDate { break }
                if current > rangeEnd { break }

                if current >= rangeStart {
                    let day = calendar.component(.day, from: current)
                    let occurrenceMonth = calendar.component(.month, from: current)
                    let occurrenceYear = calendar.component(.year, from: current)
                    if occurrenceYear == year, occurrenceMonth == month, day >= fromDay, day <= throughDay {
                        totals[day, default: 0] += amount
                    } else if occurrenceYear > year
                        || (occurrenceYear == year && occurrenceMonth > month) {
                        break
                    }
                }

                guard let next = item.recurrence.nextOccurrence(after: current, calendar: calendar) else {
                    break
                }
                occurrence = next
            }
        }

        return totals
    }

    // MARK: - Variable (lookback non-recurring average)

    static func averageVariableAmountsByDay(
        historicalExpenses: [Transaction],
        targetYear: Int,
        targetMonth: Int,
        fromDay: Int,
        throughDay: Int,
        lookbackMonths: Int = defaultLookbackMonths,
        calendar: Calendar = .current
    ) -> [Int: Double] {
        guard fromDay <= throughDay,
              let targetMonthStart = calendar.date(
                from: DateComponents(year: targetYear, month: targetMonth, day: 1)
              )
        else { return [:] }

        let lookback = max(1, lookbackMonths)
        var sums: [Int: Double] = [:]
        var counts: [Int: Int] = [:]

        for offset in 1...lookback {
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: targetMonthStart)
            else { continue }
            let components = calendar.dateComponents([.year, .month], from: monthDate)
            guard let priorYear = components.year, let priorMonth = components.month else { continue }
            let priorLastDay = daysInMonth(month: priorMonth, year: priorYear, calendar: calendar)

            var dailyNonRecurring: [Int: Double] = [:]
            for transaction in historicalExpenses where transaction.type == .expense {
                guard !transaction.isRecurringGenerated else { continue }
                let date = Date(timeIntervalSince1970: transaction.date)
                let parts = calendar.dateComponents([.year, .month, .day], from: date)
                guard parts.year == priorYear,
                      parts.month == priorMonth,
                      let day = parts.day
                else { continue }
                dailyNonRecurring[day, default: 0] += transaction.totalAmount
            }

            for day in fromDay...min(throughDay, priorLastDay) {
                sums[day, default: 0] += dailyNonRecurring[day] ?? 0
                counts[day, default: 0] += 1
            }
        }

        var averages: [Int: Double] = [:]
        for day in fromDay...throughDay {
            guard let count = counts[day], count > 0 else {
                averages[day] = 0
                continue
            }
            averages[day] = (sums[day] ?? 0) / Double(count)
        }
        return averages
    }

    static func daysInMonth(month: Int, year: Int, calendar: Calendar = .current) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date)
        else { return 0 }
        return range.count
    }
}
