//
//  CampaignStatus.swift
//  Xpnse
//

import Foundation

/// Persisted lifecycle status for an education campaign.
enum CampaignStatus: String, Codable, Equatable, Sendable {
    /// Never presented.
    case notStarted
    /// Shown at least once; may still re-qualify after dismiss.
    case presented
    /// Terminal — user completed the intended action.
    case completed
    /// Terminal — user explicitly declined.
    case declined
}
