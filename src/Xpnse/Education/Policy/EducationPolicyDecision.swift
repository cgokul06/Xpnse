//
//  EducationPolicyDecision.swift
//  Xpnse
//

import Foundation

/// Why the global education policy blocked a new session.
enum EducationPolicyReason: Equatable, Sendable {
    case journeyAlreadyActive
    case educationSessionActive
    case completionCooldown
    case declineCooldown
    case dismissCooldown
    case actionFailureCooldown
    case waitingForEvaluationTrigger

    var debugDescription: String {
        switch self {
        case .journeyAlreadyActive: return "Journey Already Active"
        case .educationSessionActive: return "Education Session Active"
        case .completionCooldown: return "Completion Cooldown"
        case .declineCooldown: return "Decline Cooldown"
        case .dismissCooldown: return "Dismiss Cooldown"
        case .actionFailureCooldown: return "Action Failure Cooldown"
        case .waitingForEvaluationTrigger: return "Waiting For Next Trigger"
        }
    }
}

/// Result of evaluating whether a new education session may begin.
enum EducationPolicyDecision: Equatable, Sendable {
    case allowed
    case blocked(EducationPolicyReason)

    var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }

    var debugDescription: String {
        switch self {
        case .allowed:
            return "Policy Allowed"
        case .blocked(let reason):
            return "Policy Blocked: \(reason.debugDescription)"
        }
    }
}
