//
//  ReviewState.swift
//  Xpnse
//

import Foundation

struct ReviewState: Codable, Equatable {
    var installationDate: Date
    var launchCount: Int
    var activeUsageDays: Int
    /// Calendar day key `yyyy-MM-dd` in the current calendar.
    var lastActiveDay: String?
    var currentStreak: Int

    var lifetimeTransactions: Int
    var lifetimeReceiptScans: Int
    var reviewTransactionCounter: Int
    var reviewReceiptCounter: Int
    var firedTransactionMilestones: Set<Int>
    var firedReceiptMilestones: Set<Int>

    var lastPromptDate: Date?
    var lastPromptVersion: String?
    var reviewRequested: Bool
    var feedbackSubmitted: Bool
    var appStoreOpened: Bool
    var lastCriticalErrorDate: Date?
    var dismissCount: Int
    var reviewCycleCompleted: Bool
    var currentAppVersion: String

    var insightsTriggerFired: Bool
    var sevenDayStreakTriggerFired: Bool

    static func fresh(now: Date, appVersion: String) -> ReviewState {
        ReviewState(
            installationDate: now,
            launchCount: 0,
            activeUsageDays: 0,
            lastActiveDay: nil,
            currentStreak: 0,
            lifetimeTransactions: 0,
            lifetimeReceiptScans: 0,
            reviewTransactionCounter: 0,
            reviewReceiptCounter: 0,
            firedTransactionMilestones: [],
            firedReceiptMilestones: [],
            lastPromptDate: nil,
            lastPromptVersion: nil,
            reviewRequested: false,
            feedbackSubmitted: false,
            appStoreOpened: false,
            lastCriticalErrorDate: nil,
            dismissCount: 0,
            reviewCycleCompleted: false,
            currentAppVersion: appVersion,
            insightsTriggerFired: false,
            sevenDayStreakTriggerFired: false
        )
    }
}

/// Read-only snapshot for feedback upload metadata.
struct ReviewStateSnapshot: Equatable {
    let lifetimeTransactions: Int
    let lifetimeReceiptScans: Int
    let recurringTransactionsCount: Int
    let launchCount: Int
    let daysSinceInstall: Int
    let appVersion: String
}
