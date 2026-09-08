//
//  CampaignOutcome.swift
//  Xpnse
//

import Foundation

/// Generic result reported by the UI/coordinator after a campaign is presented.
enum CampaignOutcome: Equatable, Sendable {
    case completed
    case declined
    case dismissed
    case actionFailed
}
