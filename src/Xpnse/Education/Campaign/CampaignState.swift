//
//  CampaignState.swift
//  Xpnse
//

import Foundation

/// Persisted lifecycle snapshot for a single education campaign.
struct CampaignState: Codable, Equatable, Sendable {
    let campaignID: String
    var status: CampaignStatus
    var firstPresentedDate: Date?
    var lastPresentedDate: Date?
    var completedDate: Date?
    var declinedDate: Date?
    var presentationCount: Int
    var dismissedCount: Int

    init(
        campaignID: String,
        status: CampaignStatus,
        firstPresentedDate: Date? = nil,
        lastPresentedDate: Date? = nil,
        completedDate: Date? = nil,
        declinedDate: Date? = nil,
        presentationCount: Int = 0,
        dismissedCount: Int = 0
    ) {
        self.campaignID = campaignID
        self.status = status
        self.firstPresentedDate = firstPresentedDate
        self.lastPresentedDate = lastPresentedDate
        self.completedDate = completedDate
        self.declinedDate = declinedDate
        self.presentationCount = presentationCount
        self.dismissedCount = dismissedCount
    }

    static func fresh(campaignID: String) -> CampaignState {
        CampaignState(campaignID: campaignID, status: .notStarted)
    }
}
