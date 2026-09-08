//
//  JourneyDependencyEvaluator.swift
//  Xpnse
//

import Foundation

/// Evaluates declarative journey prerequisites against persisted campaign states.
enum JourneyDependencyEvaluator {
    /// Returns the first unsatisfied prerequisite reason, or `nil` when all are satisfied.
    static func firstUnsatisfied(
        prerequisites: [JourneyPrerequisite],
        states: CampaignStatesSnapshot
    ) -> CampaignDecisionReason? {
        for prerequisite in prerequisites {
            guard let state = states.state(for: prerequisite.journeyID) else {
                return .missingPrerequisite(journeyID: prerequisite.journeyID)
            }
            guard prerequisite.requiredStatus.isSatisfied(by: state.status) else {
                return .prerequisiteNotCompleted(
                    journeyID: prerequisite.journeyID,
                    requiredStatus: prerequisite.requiredStatus,
                    actualStatus: state.status
                )
            }
        }
        return nil
    }
}
