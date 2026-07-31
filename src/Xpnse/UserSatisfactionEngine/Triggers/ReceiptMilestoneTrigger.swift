//
//  ReceiptMilestoneTrigger.swift
//  Xpnse
//

import Foundation

struct ReceiptMilestoneTrigger: TriggerEvaluating {
    let priority = 4
    static let milestones = [20, 50, 100]
    static let cycleMax = 100

    func evaluate(state: ReviewState, event: SatisfactionEvent) -> TriggerMatch? {
        guard event == .receiptScanned else { return nil }
        guard let milestone = Self.milestones.last(where: {
            state.reviewReceiptCounter >= $0 && !state.firedReceiptMilestones.contains($0)
        }) else {
            return nil
        }

        return TriggerMatch(
            analyticsEvent: .triggerReceiptMilestone,
            parameters: ["milestone": "\(milestone)"],
            apply: { state in
                state.firedReceiptMilestones.insert(milestone)
            }
        )
    }
}
