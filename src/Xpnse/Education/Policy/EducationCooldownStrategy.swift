//
//  EducationCooldownStrategy.swift
//  Xpnse
//

import Foundation

/// Application events that may open a new education session after the previous one ends.
enum EducationSessionStartTrigger: Equatable, Sendable {
    case appLaunched
    case appBecameActive
    case transactionAdded
    case recurringTransactionCreated

    func matches(_ event: EducationEvent) -> Bool {
        switch (self, event) {
        case (.appLaunched, .appLaunched),
             (.appBecameActive, .appBecameActive),
             (.transactionAdded, .transactionAdded),
             (.recurringTransactionCreated, .recurringTransactionCreated):
            return true
        default:
            return false
        }
    }
}

/// Reusable cooldown rules. Values live in `EducationPolicyConfiguration`, not the engine.
enum EducationCooldownStrategy: Equatable, Sendable {
    case none
    case untilNextEvaluationTrigger
    case untilReturnedToHome
    case untilNextLaunch
    case untilNextForeground
    case minimumAppLaunchCount(Int)
    case minimumActiveDays(Int)
    case minimumTransactions(Int)
    case minimumElapsedTime(TimeInterval)
    case anyOf([EducationCooldownStrategy])
    case allOf([EducationCooldownStrategy])
}
