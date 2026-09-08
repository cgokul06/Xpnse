//
//  EducationOpportunity.swift
//  Xpnse
//

import Foundation

/// Contract between campaign logic and the presentation layer for a single education moment.
struct EducationOpportunity: Equatable, Sendable, Identifiable {
    let campaignID: String
    let priority: Int
    let sheetModel: EducationSheetModel
    let primaryAction: EducationJourneyAction
    let metadata: [String: String]?

    var id: String { campaignID }

    init(
        campaignID: String,
        priority: Int,
        sheetModel: EducationSheetModel,
        primaryAction: EducationJourneyAction,
        metadata: [String: String]? = nil
    ) {
        self.campaignID = campaignID
        self.priority = priority
        self.sheetModel = sheetModel
        self.primaryAction = primaryAction
        self.metadata = metadata
    }
}
