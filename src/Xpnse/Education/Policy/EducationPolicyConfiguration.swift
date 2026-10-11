//
//  EducationPolicyConfiguration.swift
//  Xpnse
//

import Foundation

/// Configurable global education policy. Keep values here rather than inside the engine.
struct EducationPolicyConfiguration: Equatable, Sendable {
    var completed: EducationCooldownStrategy
    var declined: EducationCooldownStrategy
    var dismissed: EducationCooldownStrategy
    var actionFailed: EducationCooldownStrategy
    var sessionStartTriggers: [EducationSessionStartTrigger]

    static let defaultDeclineMinimumElapsedTime: TimeInterval = 10 * 60

    static let `default` = EducationPolicyConfiguration(
        completed: .anyOf([
            .untilNextEvaluationTrigger,
            .untilReturnedToHome
        ]),
        declined: .allOf([
            .minimumElapsedTime(defaultDeclineMinimumElapsedTime),
            .untilNextEvaluationTrigger
        ]),
        dismissed: .untilNextEvaluationTrigger,
        actionFailed: .untilNextEvaluationTrigger,
        sessionStartTriggers: [.appLaunched, .appBecameActive, .transactionAdded, .recurringTransactionCreated]
    )

    func strategy(for outcome: CampaignOutcome) -> EducationCooldownStrategy {
        switch outcome {
        case .completed: return completed
        case .declined: return declined
        case .dismissed: return dismissed
        case .actionFailed: return actionFailed
        }
    }

    func canStartSession(with event: EducationEvent) -> Bool {
        sessionStartTriggers.contains { $0.matches(event) }
    }
}
