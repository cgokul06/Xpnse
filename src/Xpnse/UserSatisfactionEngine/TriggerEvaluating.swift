//
//  TriggerEvaluating.swift
//  Xpnse
//

import Foundation

struct TriggerMatch {
    let analyticsEvent: SatisfactionAnalyticsEvent
    let parameters: [String: String]
    /// Mutates state to record that this trigger fired.
    let apply: (inout ReviewState) -> Void
}

protocol TriggerEvaluating {
    /// Priority lower = higher precedence (1 = highest).
    var priority: Int { get }
    func evaluate(state: ReviewState, event: SatisfactionEvent) -> TriggerMatch?
}
