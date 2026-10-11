//
//  RequiredJourneyStatus.swift
//  Xpnse
//

import Foundation

/// Describes which persisted campaign status satisfies a journey prerequisite.
enum RequiredJourneyStatus: Equatable, Sendable {
    case completed
    case completedOrDeclined

    func isSatisfied(by status: CampaignStatus) -> Bool {
        switch self {
        case .completed:
            return status == .completed
        case .completedOrDeclined:
            return status == .completed || status == .declined
        }
    }
}
