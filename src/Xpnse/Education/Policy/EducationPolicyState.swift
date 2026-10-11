//
//  EducationPolicyState.swift
//  Xpnse
//

import Foundation

/// One in-memory education session. At most one may exist at a time.
struct EducationSession: Codable, Equatable, Sendable {
    let id: UUID
    let journeyID: String
    let startedAt: Date
}

/// Persisted global education behaviour, independent of per-journey `CampaignState`.
struct EducationPolicyState: Codable, Equatable, Sendable {
    var lastPresentedJourneyID: String?
    var lastJourneyOutcome: CampaignOutcome?
    var lastEducationTimestamp: Date?
    var lastEducationAppLaunchCount: Int?
    var lastEducationActiveDayCount: Int?
    var lastEducationTransactionCount: Int?
    var sessionActive: Bool
    var currentSessionID: UUID?
    var awaitingEvaluationTrigger: Bool
    var appLaunchCount: Int
    var activeDayCount: Int
    var lastRecordedActiveDay: Date?

    static let fresh = EducationPolicyState(
        lastPresentedJourneyID: nil,
        lastJourneyOutcome: nil,
        lastEducationTimestamp: nil,
        lastEducationAppLaunchCount: nil,
        lastEducationActiveDayCount: nil,
        lastEducationTransactionCount: nil,
        sessionActive: false,
        currentSessionID: nil,
        awaitingEvaluationTrigger: false,
        appLaunchCount: 0,
        activeDayCount: 0,
        lastRecordedActiveDay: nil
    )

    var currentSession: EducationSession? {
        guard sessionActive, let currentSessionID, let lastPresentedJourneyID, let lastEducationTimestamp else {
            return nil
        }
        return EducationSession(
            id: currentSessionID,
            journeyID: lastPresentedJourneyID,
            startedAt: lastEducationTimestamp
        )
    }
}
