//
//  RequiredJourneyStatus.swift
//  Xpnse
//

import Foundation

/// Describes which persisted campaign status satisfies a journey prerequisite.
enum RequiredJourneyStatus: Equatable, Sendable {
    case completed

    func isSatisfied(by status: CampaignStatus) -> Bool {
        switch self {
        case .completed:
            return status == .completed
        }
    }
}
