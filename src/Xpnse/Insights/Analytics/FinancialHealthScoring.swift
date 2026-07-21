//
//  FinancialHealthScoring.swift
//  Xpnse
//

import Foundation

struct FinancialHealthBreakdown: Codable, Equatable, Sendable {
    let savingsScore: Double
    let spendingScore: Double
    let subscriptionScore: Double
    let stabilityScore: Double
    let trendScore: Double
    let totalScore: Double
    let finalStars: Int
    let reasons: [String]
}

struct FinancialHealthScoringInput: Sendable {
    let forecast: InsightsForecast
    let focusYear: Int
    let focusMonth: Int
    let monthSummaries: [InsightsMonthSummary]
    let completedBaselineMonths: [(year: Int, month: Int)]
    let transactions: [Transaction]
    let events: [InsightsFinancialEvent]
    let subscriptionShareOfExpense: Double
    let subscriptions: [InsightsSubscription]
    let discretionaryCategoryIds: Set<String>
    let calendar: Calendar
}

enum FinancialHealthScoring {
    /// Deterministic 5-component score. Never uses AI.
    static func score(_ input: FinancialHealthScoringInput) -> FinancialHealthBreakdown {
        var reasons: [String] = []

        let savings = savingsScore(forecast: input.forecast, reasons: &reasons)
        let spending = spendingDisciplineScore(input: input, reasons: &reasons)
        let subscription = subscriptionScore(input: input, reasons: &reasons)
        let stability = stabilityScore(input: input, reasons: &reasons)
        let trend = trendBonus(input: input, reasons: &reasons)

        let total = savings + spending + subscription + stability + trend
        let stars = Int(min(5.0, max(1.0, total.rounded())))

        reasons.append(
            String(
                format: "Total score %.2f/5.0 → %d stars (savings %.2f, discipline %.2f, subscriptions %.2f, stability %.2f, trend %.2f).",
                total, stars, savings, spending, subscription, stability, trend
            )
        )

        return FinancialHealthBreakdown(
            savingsScore: savings,
            spendingScore: spending,
            subscriptionScore: subscription,
            stabilityScore: stability,
            trendScore: trend,
            totalScore: total,
            finalStars: stars,
            reasons: reasons
        )
    }

    // MARK: - 1. Savings (2.0)

    private static func savingsScore(
        forecast: InsightsForecast,
        reasons: inout [String]
    ) -> Double {
        guard forecast.expectedIncome > 0.01 else {
            reasons.append("No forecast income available for savings score (+0.0 / 2.0).")
            return 0
        }

        let rate = forecast.expectedSavings / forecast.expectedIncome
        let pct = Int((rate * 100).rounded())

        let points: Double
        switch rate {
        case ..<0.05:
            points = 0
            reasons.append("Forecast savings rate \(pct)% is below 5% (+0.0 / 2.0).")
        case 0.05..<0.10:
            points = 0.5
            reasons.append("Forecast savings rate \(pct)% is 5–10% (+0.5 / 2.0).")
        case 0.10..<0.15:
            points = 1.0
            reasons.append("Forecast savings rate \(pct)% is 10–15% (+1.0 / 2.0).")
        case 0.15..<0.20:
            points = 1.5
            reasons.append("Forecast savings rate \(pct)% is 15–20% (+1.5 / 2.0).")
        case 0.20...0.30:
            points = 2.0
            reasons.append("Forecast savings rate \(pct)% is in the optimal 20–30% band (+2.0 / 2.0).")
        case 0.30..<0.40:
            points = 1.9
            reasons.append("Forecast savings rate \(pct)% is 30–40% (+1.9 / 2.0).")
        default:
            points = 1.8
            reasons.append("Forecast savings rate \(pct)% is above 40% (+1.8 / 2.0).")
        }
        return points
    }

    // MARK: - 2. Spending discipline (1.0)

    private static func spendingDisciplineScore(
        input: FinancialHealthScoringInput,
        reasons: inout [String]
    ) -> Double {
        guard !input.discretionaryCategoryIds.isEmpty else {
            reasons.append("No discretionary categories classified (+1.0 / 1.0 spending discipline).")
            return 1.0
        }

        var totalDeduction = 0.0
        let focusKey = (input.focusYear, input.focusMonth)

        for categoryId in input.discretionaryCategoryIds.sorted() {
            let focusSpend = categorySpend(
                transactions: input.transactions,
                year: focusKey.0,
                month: focusKey.1,
                categoryId: categoryId,
                calendar: input.calendar,
                events: input.events,
                excludeEvents: false
            )
            let priorMonths = input.completedBaselineMonths
            guard !priorMonths.isEmpty else { continue }

            let priorTotals = priorMonths.map {
                categorySpend(
                    transactions: input.transactions,
                    year: $0.year,
                    month: $0.month,
                    categoryId: categoryId,
                    calendar: input.calendar,
                    events: [],
                    excludeEvents: false
                )
            }
            let average = priorTotals.reduce(0, +) / Double(priorTotals.count)
            guard average > 0.01, focusSpend > average else { continue }

            let variancePct = ((focusSpend - average) / average) * 100
            let deduction = varianceDeduction(variancePct)
            guard deduction > 0 else { continue }

            totalDeduction += deduction
            let name = CategoryStore.shared.categoryDisplayName(for: categoryId)
            reasons.append(
                String(
                    format: "%@ is %.0f%% above your usual level this month (−%.1f spending discipline).",
                    name, variancePct, deduction
                )
            )
        }

        let capped = min(1.0, totalDeduction)
        let score = max(0, 1.0 - capped)
        if totalDeduction == 0 {
            reasons.append("Discretionary spending within normal variance (+1.0 / 1.0 spending discipline).")
        } else {
            reasons.append(
                String(format: "Spending discipline score %.1f / 1.0 after %.1f total deduction.", score, capped)
            )
        }
        return score
    }

    private static func varianceDeduction(_ variancePct: Double) -> Double {
        switch variancePct {
        case ...10: return 0
        case 10..<20: return 0.1
        case 20..<35: return 0.2
        case 35..<50: return 0.4
        default: return 0.6
        }
    }

    // MARK: - 3. Subscriptions (0.5)

    private static func subscriptionScore(
        input: FinancialHealthScoringInput,
        reasons: inout [String]
    ) -> Double {
        let sharePct = input.subscriptionShareOfExpense * 100
        var points: Double
        switch input.subscriptionShareOfExpense {
        case ...0.05:
            points = 0.5
            reasons.append("Subscriptions are \(Int(sharePct.rounded()))% of expenses (+0.5 / 0.5).")
        case 0.05..<0.08:
            points = 0.4
            reasons.append("Subscriptions are \(Int(sharePct.rounded()))% of expenses (+0.4 / 0.5).")
        case 0.08..<0.10:
            points = 0.3
            reasons.append("Subscriptions are \(Int(sharePct.rounded()))% of expenses (+0.3 / 0.5).")
        case 0.10..<0.15:
            points = 0.2
            reasons.append("Subscriptions are \(Int(sharePct.rounded()))% of expenses (+0.2 / 0.5).")
        default:
            points = 0
            reasons.append("Subscriptions are \(Int(sharePct.rounded()))% of expenses (+0.0 / 0.5).")
        }

        return max(0, points)
    }

    // MARK: - 4. Stability (1.0) — current month only

    private static func stabilityScore(
        input: FinancialHealthScoringInput,
        reasons: inout [String]
    ) -> Double {
        var score = 1.0
        let forecast = input.forecast

        if forecast.expectedIncome > 0.01 {
            if forecast.expectedSavings < 0 {
                score -= 0.5
                reasons.append("This month's forecast ends with negative savings (−0.5 stability).")
            } else {
                let rate = forecast.expectedSavings / forecast.expectedIncome
                if rate < 0.05 {
                    score -= 0.25
                    reasons.append("Forecast month-end savings rate is below 5% (−0.25 stability).")
                }
            }
        }

        let focusExpense = monthSummary(
            for: (input.focusYear, input.focusMonth),
            in: input.monthSummaries
        )?.expense ?? forecast.expectedExpense
        let eventTotal = input.events.filter(\.excludeFromLifestyle).reduce(0.0) { $0 + $1.amount }
        if focusExpense > 0.01, eventTotal / focusExpense > 0.20 {
            score -= 0.2
            reasons.append("Large one-time expenses this month reduce spending flexibility (−0.2 stability).")
        }

        if !input.discretionaryCategoryIds.isEmpty, !input.completedBaselineMonths.isEmpty {
            let focusDiscretionary = discretionarySpend(
                transactions: input.transactions,
                year: input.focusYear,
                month: input.focusMonth,
                discretionaryIds: input.discretionaryCategoryIds,
                calendar: input.calendar,
                events: input.events,
                excludeEvents: true
            )
            let priorTotals = input.completedBaselineMonths.map {
                discretionarySpend(
                    transactions: input.transactions,
                    year: $0.year,
                    month: $0.month,
                    discretionaryIds: input.discretionaryCategoryIds,
                    calendar: input.calendar,
                    events: [],
                    excludeEvents: false
                )
            }
            let priorAverage = priorTotals.reduce(0, +) / Double(priorTotals.count)
            if priorAverage > 0.01, focusDiscretionary > priorAverage * 1.25 {
                score -= 0.2
                reasons.append(
                    "Discretionary spending this month is well above your usual level (−0.2 stability)."
                )
            }
        }

        let finalScore = max(0, score)
        if finalScore >= 1.0 {
            reasons.append("This month's spending path looks stable (+1.0 / 1.0 stability).")
        } else {
            reasons.append(String(format: "Stability score %.1f / 1.0.", finalScore))
        }
        return finalScore
    }

    // MARK: - 5. Trend bonus (0.5) — current month momentum only

    private static func trendBonus(
        input: FinancialHealthScoringInput,
        reasons: inout [String]
    ) -> Double {
        var bonus = 0.0
        let forecast = input.forecast

        if forecast.expectedIncome > 0.01 {
            let rate = forecast.expectedSavings / forecast.expectedIncome
            if (0.20...0.30).contains(rate) {
                bonus += 0.25
                reasons.append("Forecast savings rate is in the optimal band this month (+0.25 trend).")
            } else if rate >= 0.15 {
                bonus += 0.15
                reasons.append("Forecast savings rate is healthy this month (+0.15 trend).")
            }
        }

        if forecast.confidence >= 0.7 {
            bonus += 0.15
            reasons.append("Month-end forecast confidence is high (+0.15 trend).")
        }

        if !input.discretionaryCategoryIds.isEmpty, !input.completedBaselineMonths.isEmpty {
            let focusDiscretionary = discretionarySpend(
                transactions: input.transactions,
                year: input.focusYear,
                month: input.focusMonth,
                discretionaryIds: input.discretionaryCategoryIds,
                calendar: input.calendar,
                events: input.events,
                excludeEvents: true
            )
            let priorTotals = input.completedBaselineMonths.map {
                discretionarySpend(
                    transactions: input.transactions,
                    year: $0.year,
                    month: $0.month,
                    discretionaryIds: input.discretionaryCategoryIds,
                    calendar: input.calendar,
                    events: [],
                    excludeEvents: false
                )
            }
            let priorAverage = priorTotals.reduce(0, +) / Double(priorTotals.count)
            if priorAverage > 0.01, focusDiscretionary <= priorAverage * 1.05 {
                bonus += 0.1
                reasons.append("Discretionary spending is near your usual level this month (+0.1 trend).")
            }
        }

        if input.events.filter(\.excludeFromLifestyle).isEmpty {
            bonus += 0.1
            reasons.append("No large one-off expenses detected this month (+0.1 trend).")
        }

        let capped = min(0.5, bonus)
        if capped == 0 {
            reasons.append("No current-month momentum bonuses (+0.0 / 0.5 trend).")
        } else {
            reasons.append(String(format: "Trend bonus %.1f / 0.5.", capped))
        }
        return capped
    }

    // MARK: - Helpers

    private static func monthSummary(
        for key: (year: Int, month: Int),
        in summaries: [InsightsMonthSummary]
    ) -> InsightsMonthSummary? {
        summaries.first { $0.year == key.year && $0.monthNumber == key.month }
    }

    private static func categorySpend(
        transactions: [Transaction],
        year: Int,
        month: Int,
        categoryId: String,
        calendar: Calendar,
        events: [InsightsFinancialEvent],
        excludeEvents: Bool
    ) -> Double {
        let total = transactions
            .filter { tx in
                guard tx.type == .expense else { return false }
                let date = Date(timeIntervalSince1970: tx.date)
                let comps = calendar.dateComponents([.year, .month], from: date)
                guard comps.year == year, comps.month == month else { return false }
                return CategoryStore.shared.canonicalCategoryId(for: tx.categoryId) == categoryId
            }
            .reduce(0.0) { $0 + $1.totalAmount }

        guard excludeEvents else { return total }
        let excluded = events.filter(\.excludeFromLifestyle).reduce(0.0) { $0 + $1.amount }
        return max(0, total - excluded)
    }

    private static func discretionarySpend(
        transactions: [Transaction],
        year: Int,
        month: Int,
        discretionaryIds: Set<String>,
        calendar: Calendar,
        events: [InsightsFinancialEvent],
        excludeEvents: Bool
    ) -> Double {
        discretionaryIds.reduce(0.0) { partial, categoryId in
            partial + categorySpend(
                transactions: transactions,
                year: year,
                month: month,
                categoryId: categoryId,
                calendar: calendar,
                events: events,
                excludeEvents: excludeEvents
            )
        }
    }

}
