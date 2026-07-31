//
//  TriggerCoordinator.swift
//  Xpnse
//

import Foundation

struct TriggerCoordinator {
    private let triggers: [any TriggerEvaluating]

    init(triggers: [any TriggerEvaluating] = TriggerCoordinator.defaultTriggers) {
        self.triggers = triggers.sorted { $0.priority < $1.priority }
    }

    static var defaultTriggers: [any TriggerEvaluating] {
        [
            InsightsGeneratedTrigger(),
            SevenDayStreakTrigger(),
            TransactionMilestoneTrigger(),
            ReceiptMilestoneTrigger()
        ]
    }

    /// Returns the highest-priority match, if any.
    func evaluate(state: ReviewState, event: SatisfactionEvent) -> TriggerMatch? {
        for trigger in triggers {
            if let match = trigger.evaluate(state: state, event: event) {
                return match
            }
        }
        return nil
    }
}
