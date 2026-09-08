//
//  EducationCampaignStateStore.swift
//  Xpnse
//

import Foundation

/// Persistence contract for campaign lifecycle state. Storage implementation is added later.
protocol EducationCampaignStateStore: Sendable {
    func load(campaignID: String) -> CampaignState?
    func save(_ state: CampaignState)
}

extension EducationCampaignStateStore {
    func loadOrFresh(campaignID: String) -> CampaignState {
        load(campaignID: campaignID) ?? .fresh(campaignID: campaignID)
    }
}
