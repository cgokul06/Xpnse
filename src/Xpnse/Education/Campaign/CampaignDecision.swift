//
//  CampaignDecision.swift
//  Xpnse
//

import Foundation

/// Reason a campaign is not eligible. Primarily for debugging and unit tests.
enum CampaignDecisionReason: Equatable, Sendable {
    case alreadyCompleted
    case alreadyDeclined
    case incomeExists
    case recurringIncomeExists
    case transactionsExist
    case tooFewTransactions
    case customCategoryExists
    case missingPrerequisite(journeyID: String)
    case prerequisiteNotCompleted(
        journeyID: String,
        requiredStatus: RequiredJourneyStatus,
        actualStatus: CampaignStatus
    )
    case notificationAlreadyGranted
    case educationCooldownActive
    case custom(String)
}

/// Result of pure campaign evaluation.
enum CampaignDecision: Equatable, Sendable {
    case eligible
    case notEligible(CampaignDecisionReason)
}
