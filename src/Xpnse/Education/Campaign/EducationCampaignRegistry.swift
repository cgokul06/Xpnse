//
//  EducationCampaignRegistry.swift
//  Xpnse
//

import Foundation

/// Registry of education campaigns sorted by priority (lower = higher precedence).
struct EducationCampaignRegistry: Sendable {
    let campaigns: [any EducationCampaign]

    init(campaigns: [any EducationCampaign]) {
        self.campaigns = campaigns.sorted {
            $0.identity.priority < $1.identity.priority
        }
    }

    func campaign(id: String) -> (any EducationCampaign)? {
        campaigns.first { $0.identity.id == id }
    }

    func state(for campaignID: String, in states: [CampaignState]) -> CampaignState? {
        CampaignStatesSnapshot.from(states).state(for: campaignID)
    }
}
