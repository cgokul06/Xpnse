//
//  ReviewOpportunity.swift
//  Xpnse
//

import Foundation

enum ReviewTriggerSource: String, Equatable, Sendable {
    case insightsGenerated
    case sevenDayStreak
    case transactionMilestone
    case receiptMilestone
}

/// Published by `UserSatisfactionEngine` when a review should be considered.
/// Presentation timing is owned by `UserEngagementCoordinator`.
struct ReviewOpportunity: Identifiable, Equatable, Sendable {
    let id: UUID
    let trigger: ReviewTriggerSource
    let title: String
    let message: String
    let createdAt: Date
    /// Lower value = higher priority (matches trigger priority).
    let priority: Int
    /// Optional milestone value for analytics / copy.
    let milestone: Int?

    init(
        id: UUID = UUID(),
        trigger: ReviewTriggerSource,
        title: String,
        message: String,
        createdAt: Date,
        priority: Int,
        milestone: Int? = nil
    ) {
        self.id = id
        self.trigger = trigger
        self.title = title
        self.message = message
        self.createdAt = createdAt
        self.priority = priority
        self.milestone = milestone
    }

    /// Shared subtitle for every review prompt — keep situational copy out of the UI.
    static let genericSubtitle = "Your feedback helps us build a better app for everyone."

    static func make(
        analyticsEvent: SatisfactionAnalyticsEvent,
        parameters: [String: String],
        now: Date
    ) -> ReviewOpportunity? {
        switch analyticsEvent {
        case .triggerInsights:
            return ReviewOpportunity(
                trigger: .insightsGenerated,
                title: genericSubtitle,
                message: genericSubtitle,
                createdAt: now,
                priority: 1
            )
        case .triggerSevenDayStreak:
            return ReviewOpportunity(
                trigger: .sevenDayStreak,
                title: genericSubtitle,
                message: genericSubtitle,
                createdAt: now,
                priority: 2
            )
        case .triggerTransactionMilestone:
            let milestone = Int(parameters["milestone"] ?? "") ?? 0
            return ReviewOpportunity(
                trigger: .transactionMilestone,
                title: genericSubtitle,
                message: genericSubtitle,
                createdAt: now,
                priority: 3,
                milestone: milestone
            )
        case .triggerReceiptMilestone:
            let milestone = Int(parameters["milestone"] ?? "") ?? 0
            return ReviewOpportunity(
                trigger: .receiptMilestone,
                title: genericSubtitle,
                message: genericSubtitle,
                createdAt: now,
                priority: 4,
                milestone: milestone
            )
        default:
            return nil
        }
    }
}

/// Engagement experiences the coordinator may present.
enum EngagementPresentation: Identifiable, Equatable {
    case appReview(ReviewOpportunity)

    var id: UUID {
        switch self {
        case .appReview(let opportunity):
            return opportunity.id
        }
    }
}
