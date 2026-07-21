//
//  FinancialHealthRules.swift
//  Xpnse
//

import Foundation

/// Soft financial guidance evaluated against personal history — not hard universal caps.
enum FinancialHealthRules {
    /// Recommended savings rate band (of income).
    static let savingsRateHealthyMin = 0.20
    static let savingsRateHealthyMax = 0.30

    /// Soft subscription share of expense.
    static let subscriptionsSoftMax = 0.10
    static let subscriptionsComfortableMax = 0.05

    /// Lookback months with less than this fraction of peer months' data volume
    /// are treated as incomplete and excluded from baseline analysis.
    static let monthCompletenessMinimumRatio = 0.70

    /// Category utilization vs personal rolling average ("usual").
    /// - under: &lt; 80% of usual (UI: "Below usual", green)
    /// - withinRange: 80%…105% of usual (UI: "Near usual", yellow)
    /// - approaching: &gt;105%…120% of usual (UI: "Above usual", orange)
    /// - over: &gt; 120% of usual (UI: "Well above usual", red)
    static let categoryWithinBand: ClosedRange<Double> = 0.80...1.05
    static let categoryApproachingMax = 1.20

    /// Stable MoM change band (±).
    static let stableChangePercent = 8.0

    /// Absolute floor for generic outliers (legacy / outlier list).
    static let outlierMultipleOfMedian = 3.0
    static let outlierAbsoluteFloor = 250.0

    /// Detected events: rare / annual-style spends — not recurring or mild bumps.
    /// Category-month total vs that category's other months.
    static let eventCategorySpikeMultipleOfAverage = 2.5
    static let eventCategorySpikeMultipleOfPriorMax = 1.75
    static let eventCategoryAbsoluteFloor = 400.0
    /// Single transaction vs typical size in the same category.
    static let eventTxnMultipleOfCategoryMedian = 5.0
    static let eventTxnAbsoluteFloor = 500.0

    /// Income bonus: month income above this multiple of recent average.
    static let incomeBonusMultiple = 1.4

    static func categoryStatus(utilization: Double) -> InsightsCategoryHealthStatus {
        if utilization > categoryApproachingMax { return .over }
        if utilization > categoryWithinBand.upperBound { return .approaching }
        if utilization < categoryWithinBand.lowerBound { return .under }
        return .withinRange
    }

    static func changeDirection(percentChange: Double?) -> InsightsChangeDirection {
        guard let percentChange else { return .stable }
        if percentChange > stableChangePercent { return .up }
        if percentChange < -stableChangePercent { return .down }
        return .stable
    }

    static func rulesPromptText() -> String {
        """
        Soft guidance (evaluate against the snapshot; do not invent numbers):
        - Savings rate healthy band: \(Int(savingsRateHealthyMin * 100))–\(Int(savingsRateHealthyMax * 100))% of income.
        - Subscriptions ideally under \(Int(subscriptionsComfortableMax * 100))–\(Int(subscriptionsSoftMax * 100))% of expenses.
        - Category health uses each user's rolling average (below &lt;80%, near 80–105%, above 105–120%, well above &gt;120%).
        - Financial health stars are computed deterministically from `healthBreakdown` (savings, spending discipline, subscriptions, stability, trend). Never invent or adjust the score — only explain it using `healthBreakdown.reasons`. Discuss the current focus month only; never cite prior months.
        - Detected events are rare / annual-style category spikes (festival, insurance), not recurring bills or mild overspend.
        - Respect event tags: seasonal, medical, capital, and bonus income are temporary — do not treat them as lasting habit changes.
        - Every narrative must cover: what happened, why it matters, and what you can do next — always in second person.
        - Celebrate genuine wins. Never invent merchants, amounts, or categories absent from the snapshot.
        - Write to the reader as "you/your", never as "the user".
        """
    }
}

enum InsightsScoring {
    /// Deprecated — use `FinancialHealthScoring` for the 5-component health model.
    static func score(snapshot: InsightsSnapshot) -> Int {
        snapshot.healthBreakdown.finalStars
    }
}
