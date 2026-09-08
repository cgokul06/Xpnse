//
//  JourneyPrerequisite.swift
//  Xpnse
//

import Foundation

/// Declares that a journey depends on another journey reaching a required status.
struct JourneyPrerequisite: Equatable, Sendable {
    let journeyID: String
    let requiredStatus: RequiredJourneyStatus

    init(journeyID: String, requiredStatus: RequiredJourneyStatus) {
        self.journeyID = journeyID
        self.requiredStatus = requiredStatus
    }

    static func completed(_ journeyID: String) -> JourneyPrerequisite {
        JourneyPrerequisite(journeyID: journeyID, requiredStatus: .completed)
    }
}
