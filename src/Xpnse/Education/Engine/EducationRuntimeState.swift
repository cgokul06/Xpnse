//
//  EducationRuntimeState.swift
//  Xpnse
//

import Foundation

/// In-memory lifecycle of the Education Engine. Only one journey may be active.
enum EducationRuntimeState: Equatable, Sendable {
    /// No journey currently active.
    case idle
    /// An opportunity has been published and is waiting for user interaction.
    case presenting(journeyID: String)
    /// The user accepted the primary action and is being navigated into the feature flow.
    case performingAction(journeyID: String)
    /// The feature flow has not yet reported a final outcome.
    case waitingForOutcome(journeyID: String)

    var activeJourneyID: String? {
        switch self {
        case .idle:
            return nil
        case .presenting(let journeyID),
             .performingAction(let journeyID),
             .waitingForOutcome(let journeyID):
            return journeyID
        }
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var isPresentationPending: Bool {
        if case .presenting = self { return true }
        return false
    }

    var isWaitingForOutcome: Bool {
        if case .waitingForOutcome = self { return true }
        return false
    }

    var debugDescription: String {
        switch self {
        case .idle:
            return "idle"
        case .presenting(let journeyID):
            return "presenting(\(journeyID))"
        case .performingAction(let journeyID):
            return "performingAction(\(journeyID))"
        case .waitingForOutcome(let journeyID):
            return "waitingForOutcome(\(journeyID))"
        }
    }
}
