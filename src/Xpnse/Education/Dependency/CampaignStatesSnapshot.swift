//
//  CampaignStatesSnapshot.swift
//  Xpnse
//

import Foundation

/// Storage-agnostic lookup of campaign states for dependency evaluation.
struct CampaignStatesSnapshot: Equatable, Sendable {
    private let statesByID: [String: CampaignState]

    init(statesByID: [String: CampaignState]) {
        self.statesByID = statesByID
    }

    static func from(_ states: [CampaignState]) -> CampaignStatesSnapshot {
        var statesByID: [String: CampaignState] = [:]
        for state in states {
            statesByID[state.campaignID] = state
        }
        return CampaignStatesSnapshot(statesByID: statesByID)
    }

    func state(for campaignID: String) -> CampaignState? {
        statesByID[campaignID]
    }
}
