//
//  SevenDayStreakTrigger.swift
//  Xpnse
//

import Foundation

struct SevenDayStreakTrigger: TriggerEvaluating {
    let priority = 2
    static let requiredStreak = 7

    func evaluate(state: ReviewState, event: SatisfactionEvent) -> TriggerMatch? {
        guard !state.sevenDayStreakTriggerFired else { return nil }
        guard state.currentStreak >= Self.requiredStreak else { return nil }
        // Fire on usage-day updates (launch / active), not on every event.
        switch event {
        case .appLaunched, .appBecameActive:
            break
        default:
            return nil
        }
        return TriggerMatch(
            analyticsEvent: .triggerSevenDayStreak,
            parameters: ["streak": "\(state.currentStreak)"],
            apply: { $0.sevenDayStreakTriggerFired = true }
        )
    }
}
