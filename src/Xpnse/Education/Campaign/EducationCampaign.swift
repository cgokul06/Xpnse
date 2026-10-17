//
//  EducationCampaign.swift
//  Xpnse
//

import Foundation

/// Every education campaign conforms to this protocol. Evaluation must be pure — no UI, no mutation.
protocol EducationCampaign: Sendable {
    var identity: EducationCampaignIdentity { get }
    var prerequisites: [JourneyPrerequisite] { get }
    var completionValidator: any JourneyCompletionValidator { get }
    /// When false, the engine never publishes this campaign on its own; a host screen starts it explicitly.
    var presentsAutomatically: Bool { get }
    /// When the user just skipped this journey, the follow-up skips the decline cooldown
    /// and shows on the next launch or foreground.
    var followUpAfterSkipOf: String? { get }

    /// Feature-specific eligibility only — no terminal guard, no dependency checks.
    func evaluateFeatureEligibility(context: CampaignContext, state: CampaignState) -> CampaignDecision
}

extension EducationCampaign {
    var prerequisites: [JourneyPrerequisite] { [] }

    var presentsAutomatically: Bool { true }

    var followUpAfterSkipOf: String? { nil }

    var completionValidator: any JourneyCompletionValidator {
        TrustingJourneyCompletionValidator()
    }

    /// Evaluates eligibility given context, own persisted state, and all campaign states for dependency checks.
    func evaluate(
        context: CampaignContext,
        state: CampaignState,
        allStates: [CampaignState]
    ) -> CampaignDecision {
        if let terminal = terminalGuard(state: state) {
            return terminal
        }
        let snapshot = CampaignStatesSnapshot.from(allStates)
        if let reason = JourneyDependencyEvaluator.firstUnsatisfied(
            prerequisites: prerequisites,
            states: snapshot
        ) {
            return .notEligible(reason)
        }
        return evaluateFeatureEligibility(context: context, state: state)
    }

    /// Applies an outcome after validating completion against application state.
    func applyOutcome(
        _ outcome: CampaignOutcome,
        to state: CampaignState,
        at date: Date,
        validationContext: CompletionValidationContext
    ) -> CampaignState {
        if case .completed = outcome {
            guard completionValidator.validate(context: validationContext).isValid else {
                return state
            }
        }
        return CampaignStateTransition.applying(outcome: outcome, to: state, at: date)
    }

    /// Returns a terminal ineligibility decision when the campaign has already completed or declined.
    func terminalGuard(state: CampaignState) -> CampaignDecision? {
        switch state.status {
        case .completed:
            return .notEligible(.alreadyCompleted)
        case .declined:
            return .notEligible(.alreadyDeclined)
        case .notStarted, .presented:
            return nil
        }
    }
}
