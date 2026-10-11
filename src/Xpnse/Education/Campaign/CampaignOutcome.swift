//
//  CampaignOutcome.swift
//  Xpnse
//

import Foundation

/// Generic result reported by the UI/coordinator after a campaign is presented.
enum CampaignOutcome: String, Codable, Equatable, Sendable {
    case completed
    case declined
    case dismissed
    case actionFailed
}
