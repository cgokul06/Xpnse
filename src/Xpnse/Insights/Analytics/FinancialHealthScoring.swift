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
    /// Forecast savings rate as a whole percent (e.g. 38 for 38%).
    let forecastSavingsRatePercent: Int
    /// Plain-English comparison vs the 20–30% guide — use this in narratives.
    let savingsRateAssessment: String
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

        let forecastRate = input.forecast.expectedIncome > 0.01
            ? input.forecast.expectedSavings / input.forecast.expectedIncome
            : 0
        let forecastSavingsRatePercent = Int((forecastRate * 100).rounded())
        let savingsRateAssessment = savingsRateAssessment(for: forecastRate)

        reasons.insert(savingsRateAssessment, at: 0)

        reasons.append(
            L10n.tr(
                "health.stars.total",
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
            forecastSavingsRatePercent: forecastSavingsRatePercent,
            savingsRateAssessment: savingsRateAssessment,
            reasons: reasons
        )
    }

    /// Deterministic savings-rate wording for narratives — avoids FM misreading comparisons.
    static func savingsRateAssessment(for rate: Double) -> String {
        let pct = Int((rate * 100).rounded())
        let band = "\(Int(FinancialHealthRules.savingsRateHealthyMin * 100))–\(Int(FinancialHealthRules.savingsRateHealthyMax * 100))%"

        switch rate {
        case ..<0:
            return L10n.tr("health.rate.negative", pct)
        case 0..<0.05:
            return L10n.tr("health.rate.well_below", pct, band)
        case 0.05..<0.20:
            return L10n.tr("health.rate.below", pct, band)
        case 0.20...0.30:
            return L10n.tr("health.rate.within", pct, band)
        case 0.30..<0.40:
            return L10n.tr("health.rate.above", pct, band)
        default:
            return L10n.tr("health.rate.well_above", pct, band)
        }
    }

    // MARK: - 1. Savings (2.0)

    private static func savingsScore(
        forecast: InsightsForecast,
        reasons: inout [String]
    ) -> Double {
        guard forecast.expectedIncome > 0.01 else {
            reasons.append(L10n.tr("health.savings.no_income"))
            return 0
        }

        let rate = forecast.expectedSavings / forecast.expectedIncome
        let pct = Int((rate * 100).rounded())

        let points: Double
        switch rate {
        case ..<0.05:
            points = 0
            reasons.append(L10n.tr("health.savings.below_5", pct))
        case 0.05..<0.10:
            points = 0.5
            reasons.append(L10n.tr("health.savings.band_5_10", pct))
        case 0.10..<0.15:
            points = 1.0
            reasons.append(L10n.tr("health.savings.band_10_15", pct))
        case 0.15..<0.20:
            points = 1.5
            reasons.append(L10n.tr("health.savings.band_15_20", pct))
        case 0.20...0.30:
            points = 2.0
            reasons.append(L10n.tr("health.savings.optimal", pct))
        case 0.30..<0.40:
            points = 1.9
            reasons.append(L10n.tr("health.savings.band_30_40", pct))
        default:
            points = 1.8
            reasons.append(L10n.tr("health.savings.above_40", pct))
        }
        return points
    }

    // MARK: - 2. Spending discipline (1.0)

    private static func spendingDisciplineScore(
        input: FinancialHealthScoringInput,
        reasons: inout [String]
    ) -> Double {
        guard !input.discretionaryCategoryIds.isEmpty else {
            reasons.append(L10n.tr("health.spending.no_discretionary"))
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
                L10n.tr("health.spending.above_usual", name, variancePct, deduction)
            )
        }

        let capped = min(1.0, totalDeduction)
        let score = max(0, 1.0 - capped)
        if totalDeduction == 0 {
            reasons.append(L10n.tr("health.spending.within"))
        } else {
            reasons.append(L10n.tr("health.spending.score", score, capped))
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
        let sharePct = Int((input.subscriptionShareOfExpense * 100).rounded())
        var points: Double
        switch input.subscriptionShareOfExpense {
        case ...0.05:
            points = 0.5
        case 0.05..<0.08:
            points = 0.4
        case 0.08..<0.10:
            points = 0.3
        case 0.10..<0.15:
            points = 0.2
        default:
            points = 0
        }
        reasons.append(L10n.tr("health.subscriptions.share", sharePct, points))
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
                reasons.append(L10n.tr("health.stability.negative_savings"))
            } else {
                let rate = forecast.expectedSavings / forecast.expectedIncome
                if rate < 0.05 {
                    score -= 0.25
                    reasons.append(L10n.tr("health.stability.low_rate"))
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
            reasons.append(L10n.tr("health.stability.large_events"))
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
                reasons.append(L10n.tr("health.stability.discretionary_high"))
            }
        }

        let finalScore = max(0, score)
        if finalScore >= 1.0 {
            reasons.append(L10n.tr("health.stability.stable"))
        } else {
            reasons.append(L10n.tr("health.stability.score", finalScore))
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
                reasons.append(L10n.tr("health.trend.optimal_band"))
            } else if rate >= 0.15 {
                bonus += 0.15
                reasons.append(L10n.tr("health.trend.healthy_rate"))
            }
        }

        if forecast.confidence >= 0.7 {
            bonus += 0.15
            reasons.append(L10n.tr("health.trend.high_confidence"))
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
                reasons.append(L10n.tr("health.trend.discretionary_near"))
            }
        }

        if input.events.filter(\.excludeFromLifestyle).isEmpty {
            bonus += 0.1
            reasons.append(L10n.tr("health.trend.no_one_offs"))
        }

        let capped = min(0.5, bonus)
        if capped == 0 {
            reasons.append(L10n.tr("health.trend.none"))
        } else {
            reasons.append(L10n.tr("health.trend.bonus", capped))
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
