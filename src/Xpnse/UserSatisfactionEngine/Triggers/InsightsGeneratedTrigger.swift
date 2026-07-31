//
//  InsightsGeneratedTrigger.swift
//  Xpnse
//

import Foundation

struct InsightsGeneratedTrigger: TriggerEvaluating {
    let priority = 1

    func evaluate(state: ReviewState, event: SatisfactionEvent) -> TriggerMatch? {
        guard event == .insightsGenerated else { return nil }
        guard !state.insightsTriggerFired else { return nil }
        return TriggerMatch(
            analyticsEvent: .triggerInsights,
            parameters: [:],
            apply: { $0.insightsTriggerFired = true }
        )
    }
}
