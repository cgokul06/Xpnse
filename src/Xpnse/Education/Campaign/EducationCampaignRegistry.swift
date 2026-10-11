//
//  EducationCampaignRegistry.swift
//  Xpnse
//

import Foundation

/// Registry of education campaigns sorted by priority (lower = higher precedence).
struct EducationCampaignRegistry: Sendable {
    let campaigns: [any EducationCampaign]

    init(campaigns: [any EducationCampaign]) {
        self.campaigns = campaigns.enumerated().sorted { lhs, rhs in
            if lhs.element.identity.priority != rhs.element.identity.priority {
                return lhs.element.identity.priority < rhs.element.identity.priority
            }
            if lhs.offset != rhs.offset {
                return lhs.offset < rhs.offset
            }
            return lhs.element.identity.id < rhs.element.identity.id
        }.map(\.element)
    }

    func campaign(id: String) -> (any EducationCampaign)? {
        campaigns.first { $0.identity.id == id }
    }

    func state(for campaignID: String, in states: [CampaignState]) -> CampaignState? {
        CampaignStatesSnapshot.from(states).state(for: campaignID)
    }
}
