//
//  EducationPolicyEngine.swift
//  Xpnse
//

import Foundation

/// Pure global policy: whether a new education session may begin. Does not evaluate journeys.
struct EducationPolicyEngine: Sendable {
    let configuration: EducationPolicyConfiguration
    private let calendar: Calendar

    init(
        configuration: EducationPolicyConfiguration = .default,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.configuration = configuration
        self.calendar = calendar
    }

    func evaluate(
        policy: EducationPolicyState,
        runtime: EducationRuntimeState,
        event: EducationEvent,
        context: CampaignContext,
        now: Date
    ) -> EducationPolicyDecision {
        if !runtime.isIdle {
            return .blocked(.journeyAlreadyActive)
        }
        if policy.sessionActive {
            return .blocked(.educationSessionActive)
        }
        guard let outcome = policy.lastJourneyOutcome else {
            return .allowed
        }
        return evaluateStrategy(
            configuration.strategy(for: outcome),
            policy: policy,
            event: event,
            context: context,
            now: now,
            outcome: outcome
        )
    }

    func recordingUsage(
        policy: EducationPolicyState,
        event: EducationEvent,
        now: Date
    ) -> EducationPolicyState {
        var updated = policy
        switch event {
        case .appLaunched:
            updated.appLaunchCount += 1
            bumpActiveDay(in: &updated, now: now)
        case .appBecameActive:
            bumpActiveDay(in: &updated, now: now)
        default:
            break
        }
        return updated
    }

    func startingSession(
        policy: EducationPolicyState,
        journeyID: String,
        context: CampaignContext,
        now: Date
    ) -> EducationPolicyState {
        var updated = policy
        let sessionID = UUID()
        updated.sessionActive = true
        updated.currentSessionID = sessionID
        updated.lastPresentedJourneyID = journeyID
        updated.lastEducationTimestamp = now
        updated.lastEducationAppLaunchCount = policy.appLaunchCount
        updated.lastEducationActiveDayCount = policy.activeDayCount
        updated.lastEducationTransactionCount = context.transactionCount
        updated.awaitingEvaluationTrigger = false
        return updated
    }

    func endingSession(
        policy: EducationPolicyState,
        outcome: CampaignOutcome,
        context: CampaignContext,
        now: Date
    ) -> EducationPolicyState {
        var updated = policy
        updated.sessionActive = false
        updated.currentSessionID = nil
        updated.lastJourneyOutcome = outcome
        updated.lastEducationTimestamp = now
        updated.lastEducationAppLaunchCount = policy.appLaunchCount
        updated.lastEducationActiveDayCount = policy.activeDayCount
        updated.lastEducationTransactionCount = context.transactionCount
        updated.awaitingEvaluationTrigger = true
        return updated
    }

    func clearingAbandonedSession(_ policy: EducationPolicyState) -> EducationPolicyState {
        guard policy.sessionActive else { return policy }
        var updated = policy
        updated.sessionActive = false
        updated.currentSessionID = nil
        return updated
    }

    // MARK: - Strategy

    private func evaluateStrategy(
        _ strategy: EducationCooldownStrategy,
        policy: EducationPolicyState,
        event: EducationEvent,
        context: CampaignContext,
        now: Date,
        outcome: CampaignOutcome
    ) -> EducationPolicyDecision {
        switch strategy {
        case .none:
            return .allowed

        case .untilNextEvaluationTrigger:
            if configuration.canStartSession(with: event) {
                return .allowed
            }
            return .blocked(.waitingForEvaluationTrigger)

        case .untilReturnedToHome:
            if event == .returnedToHome {
                return .allowed
            }
            return .blocked(.waitingForEvaluationTrigger)

        case .untilNextLaunch:
            if event == .appLaunched {
                return .allowed
            }
            return .blocked(.waitingForEvaluationTrigger)

        case .untilNextForeground:
            if event == .appBecameActive {
                return .allowed
            }
            return .blocked(.waitingForEvaluationTrigger)

        case .minimumElapsedTime(let interval):
            guard let last = policy.lastEducationTimestamp else { return .allowed }
            if now.timeIntervalSince(last) >= interval {
                return .allowed
            }
            return .blocked(Self.cooldownReason(for: outcome))

        case .minimumAppLaunchCount(let minimum):
            let baseline = policy.lastEducationAppLaunchCount ?? 0
            if policy.appLaunchCount - baseline >= minimum {
                return .allowed
            }
            return .blocked(Self.cooldownReason(for: outcome))

        case .minimumActiveDays(let minimum):
            let baseline = policy.lastEducationActiveDayCount ?? 0
            if policy.activeDayCount - baseline >= minimum {
                return .allowed
            }
            return .blocked(Self.cooldownReason(for: outcome))

        case .minimumTransactions(let minimum):
            let baseline = policy.lastEducationTransactionCount ?? 0
            if context.transactionCount - baseline >= minimum {
                return .allowed
            }
            return .blocked(Self.cooldownReason(for: outcome))

        case .allOf(let strategies):
            for child in strategies {
                let decision = evaluateStrategy(
                    child,
                    policy: policy,
                    event: event,
                    context: context,
                    now: now,
                    outcome: outcome
                )
                if case .blocked = decision {
                    return decision
                }
            }
            return .allowed

        case .anyOf(let strategies):
            var firstBlock: EducationPolicyDecision?
            for child in strategies {
                let decision = evaluateStrategy(
                    child,
                    policy: policy,
                    event: event,
                    context: context,
                    now: now,
                    outcome: outcome
                )
                if case .allowed = decision {
                    return .allowed
                }
                if firstBlock == nil {
                    firstBlock = decision
                }
            }
            return firstBlock ?? .blocked(Self.cooldownReason(for: outcome))
        }
    }

    private func bumpActiveDay(in policy: inout EducationPolicyState, now: Date) {
        let day = calendar.startOfDay(for: now)
        if policy.lastRecordedActiveDay != day {
            policy.activeDayCount += 1
            policy.lastRecordedActiveDay = day
        }
    }

    private static func cooldownReason(for outcome: CampaignOutcome) -> EducationPolicyReason {
        switch outcome {
        case .completed: return .completionCooldown
        case .declined: return .declineCooldown
        case .dismissed: return .dismissCooldown
        case .actionFailed: return .actionFailureCooldown
        }
    }
}
