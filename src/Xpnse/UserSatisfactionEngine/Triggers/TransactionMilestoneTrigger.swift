//
//  TransactionMilestoneTrigger.swift
//  Xpnse
//

import Foundation

struct TransactionMilestoneTrigger: TriggerEvaluating {
    let priority = 3
    static let milestones = [20, 50, 100, 250, 500]
    static let cycleMax = 500

    func evaluate(state: ReviewState, event: SatisfactionEvent) -> TriggerMatch? {
        guard event == .transactionAdded else { return nil }
        // Highest crossed unfired milestone (covers delayed eligibility).
        guard let milestone = Self.milestones.last(where: {
            state.reviewTransactionCounter >= $0 && !state.firedTransactionMilestones.contains($0)
        }) else {
            return nil
        }

        return TriggerMatch(
            analyticsEvent: .triggerTransactionMilestone,
            parameters: ["milestone": "\(milestone)"],
            apply: { state in
                state.firedTransactionMilestones.insert(milestone)
            }
        )
    }
}
