//
//  CampaignStateTransition.swift
//  Xpnse
//

import Foundation

/// Pure state mutations for campaign lifecycle. Used by a coordinator — not by campaigns.
enum CampaignStateTransition {
    /// Records that the campaign was presented to the user.
    static func markPresented(_ state: CampaignState, at date: Date) -> CampaignState {
        var updated = state
        updated.status = .presented
        updated.presentationCount += 1
        if updated.firstPresentedDate == nil {
            updated.firstPresentedDate = date
        }
        updated.lastPresentedDate = date
        return updated
    }

    /// Applies a presentation outcome to campaign state.
    static func applying(outcome: CampaignOutcome, to state: CampaignState, at date: Date) -> CampaignState {
        var updated = state
        switch outcome {
        case .completed:
            updated.status = .completed
            updated.completedDate = date
        case .declined:
            updated.status = .declined
            updated.declinedDate = date
        case .dismissed:
            updated.status = .presented
            updated.dismissedCount += 1
        case .actionFailed:
            break
        }
        return updated
    }
}
