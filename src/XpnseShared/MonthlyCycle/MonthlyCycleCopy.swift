//
//  MonthlyCycleCopy.swift
//  XpnseShared
//

import Foundation

/// Picks calendar-month copy when start day is 1, and billing-cycle copy otherwise.
enum MonthlyCycleCopy {
    static var usesCalendarMonth: Bool {
        let configuration = MonthlyCyclePreference.current
        return configuration.kind == .fixedStartDay && configuration.startDay == 1
    }

    static func tr(_ key: String) -> String {
        L10n.tr(resolved(key))
    }

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = String(localized: String.LocalizationValue(stringLiteral: resolved(key)))
        return String(format: format, locale: .current, arguments: args)
    }

    private static func resolved(_ key: String) -> String {
        guard !usesCalendarMonth, let mapped = cycleKeyByCalendarKey[key] else { return key }
        return mapped
    }

    private static let cycleKeyByCalendarKey: [String: String] = [
        "home.prev_month": "home.prev_period",
        "home.next_month": "home.next_period",
        "insights.predicted_month_end": "insights.predicted_cycle_end",
        "insights.vs_usual_subtitle": "insights.vs_usual_subtitle.cycle",
        "insights.category_utilization": "insights.category_utilization.cycle",
        "insights.usual_legend": "insights.usual_legend.cycle",
        "insights.top_spends_empty": "insights.top_spends_empty.cycle",
        "insights.potential_recurring_subtitle": "insights.potential_recurring_subtitle.cycle",
        "insights.baselines_empty": "insights.baselines_empty.cycle",
        "insights.expense_trend_subtitle": "insights.expense_trend_subtitle.cycle",
        "insights.event.rare_spend": "insights.event.rare_spend.cycle",
        "insights.event.typical_month": "insights.event.typical_cycle",
        "health.rate.negative": "health.rate.negative.cycle",
        "health.spending.above_usual": "health.spending.above_usual.cycle",
        "health.stability.discretionary_high": "health.stability.discretionary_high.cycle",
        "health.stability.large_events": "health.stability.large_events.cycle",
        "health.stability.low_rate": "health.stability.low_rate.cycle",
        "health.stability.negative_savings": "health.stability.negative_savings.cycle",
        "health.stability.stable": "health.stability.stable.cycle",
        "health.trend.discretionary_near": "health.trend.discretionary_near.cycle",
        "health.trend.healthy_rate": "health.trend.healthy_rate.cycle",
        "health.trend.high_confidence": "health.trend.high_confidence.cycle",
        "health.trend.no_one_offs": "health.trend.no_one_offs.cycle",
        "health.trend.none": "health.trend.none.cycle",
        "health.trend.optimal_band": "health.trend.optimal_band.cycle"
    ]
}
