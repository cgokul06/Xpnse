//
//  UserSatisfactionEngine.swift
//  Xpnse
//

import Foundation
import Observation

/// Event-driven rules engine that decides when SnapLedger should request feedback.
/// Views only call `track`; presentation is owned by `UserEngagementCoordinator`.
@Observable
@MainActor
final class UserSatisfactionEngine {
    static let shared = UserSatisfactionEngine()

    /// Non-nil when a review opportunity is outstanding (queued or presented).
    private(set) var pendingReviewOpportunity: ReviewOpportunity?

    @ObservationIgnored private let store: ReviewStateStore
    @ObservationIgnored private let clock: Clock
    @ObservationIgnored private let versionProvider: AppVersionProviding
    @ObservationIgnored private let analytics: SatisfactionAnalytics
    @ObservationIgnored private let triggers: TriggerCoordinator
    @ObservationIgnored private let calendar: Calendar

    @ObservationIgnored private var state: ReviewState
    @ObservationIgnored private var criticalErrorThisSession = false
    @ObservationIgnored private var loggedEligibilityPassedThisSession = false

    @ObservationIgnored private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(
        store: ReviewStateStore = UserDefaultsReviewStateStore(),
        clock: Clock = SystemClock(),
        versionProvider: AppVersionProviding = BundleAppVersionProvider(),
        analytics: SatisfactionAnalytics = AppAnalyticsSatisfactionAdapter(),
        triggers: TriggerCoordinator = TriggerCoordinator(),
        calendar: Calendar = .current
    ) {
        self.store = store
        self.clock = clock
        self.versionProvider = versionProvider
        self.analytics = analytics
        self.triggers = triggers
        self.calendar = calendar

        let version = versionProvider.shortVersion
        if var loaded = store.load() {
            loaded.currentAppVersion = version
            self.state = loaded
        } else {
            self.state = .fresh(now: clock.now(), appVersion: version)
            store.save(self.state)
        }
    }

    // MARK: - Public API

    func track(_ event: SatisfactionEvent) {
        handle(event)
    }

    func snapshotForFeedback() -> ReviewStateSnapshot {
        let now = clock.now()
        let days = calendar.dateComponents([.day], from: state.installationDate, to: now).day ?? 0
        return ReviewStateSnapshot(
            lifetimeTransactions: state.lifetimeTransactions,
            lifetimeReceiptScans: state.lifetimeReceiptScans,
            launchCount: state.launchCount,
            daysSinceInstall: max(0, days),
            appVersion: versionProvider.shortVersion
        )
    }

    // MARK: - Event handling

    private func handle(_ event: SatisfactionEvent) {
        let now = clock.now()
        state.currentAppVersion = versionProvider.shortVersion

        switch event {
        case .appLaunched:
            state.launchCount += 1
            updateActiveUsageDay(now: now)
            criticalErrorThisSession = false

        case .appBecameActive:
            updateActiveUsageDay(now: now)

        case .appEnteredBackground:
            break

        case .transactionAdded:
            state.lifetimeTransactions += 1
            state.reviewTransactionCounter += 1

        case .receiptScanned:
            state.lifetimeReceiptScans += 1
            state.reviewReceiptCounter += 1

        case .insightsGenerated:
            break

        case .criticalErrorOccurred:
            criticalErrorThisSession = true
            state.lastCriticalErrorDate = now
            clearOpportunity()
            persist()
            return

        case .reviewPromptDismissed:
            state.dismissCount += 1
            clearOpportunity()
            analytics.log(.reviewDismissed, parameters: [:])
            persist()
            return

        case .feedbackSubmitted:
            state.feedbackSubmitted = true
            state.lastPromptVersion = versionProvider.shortVersion
            clearOpportunity()
            analytics.log(.feedbackSubmitted, parameters: [:])
            persist()
            return

        case .appStoreReviewOpened:
            state.appStoreOpened = true
            state.reviewCycleCompleted = true
            clearOpportunity()
            analytics.log(.appStoreOpened, parameters: [:])
            persist()
            return
        }

        persist()

        if state.appStoreOpened {
            return
        }

        let txnCountBefore = event == .transactionAdded
            ? state.reviewTransactionCounter - 1
            : state.reviewTransactionCounter
        let receiptCountBefore = event == .receiptScanned
            ? state.reviewReceiptCounter - 1
            : state.reviewReceiptCounter
        let crossedTxnCycleMax = event == .transactionAdded
            && txnCountBefore < TransactionMilestoneTrigger.cycleMax
            && state.reviewTransactionCounter >= TransactionMilestoneTrigger.cycleMax
        let crossedReceiptCycleMax = event == .receiptScanned
            && receiptCountBefore < ReceiptMilestoneTrigger.cycleMax
            && state.reviewReceiptCounter >= ReceiptMilestoneTrigger.cycleMax

        var processedTxnCycleMax = false
        var processedReceiptCycleMax = false

        let canPublishNewOpportunity = pendingReviewOpportunity == nil

        if canPublishNewOpportunity {
            let eligibility = EligibilityEvaluator.evaluate(
                state: state,
                now: now,
                currentVersion: versionProvider.shortVersion,
                criticalErrorThisSession: criticalErrorThisSession
            )

            switch eligibility {
            case .ineligible(let failure):
                analytics.log(.eligibilityFailed, parameters: ["reason": failure.rawValue])
            case .eligible:
                if !loggedEligibilityPassedThisSession {
                    analytics.log(.eligibilityPassed, parameters: [:])
                    loggedEligibilityPassedThisSession = true
                }

                if let match = triggers.evaluate(state: state, event: event),
                   let opportunity = ReviewOpportunity.make(
                    analyticsEvent: match.analyticsEvent,
                    parameters: match.parameters,
                    now: now
                   ) {
                    match.apply(&state)
                    state.reviewRequested = true
                    state.lastPromptDate = now
                    state.lastPromptVersion = versionProvider.shortVersion
                    pendingReviewOpportunity = opportunity
                    analytics.log(match.analyticsEvent, parameters: match.parameters)

                    if match.analyticsEvent == .triggerTransactionMilestone,
                       match.parameters["milestone"] == "\(TransactionMilestoneTrigger.cycleMax)" {
                        processedTxnCycleMax = true
                    }
                    if match.analyticsEvent == .triggerReceiptMilestone,
                       match.parameters["milestone"] == "\(ReceiptMilestoneTrigger.cycleMax)" {
                        processedReceiptCycleMax = true
                    }
                    persist()
                }
            }
        }

        if !state.appStoreOpened {
            if processedTxnCycleMax || crossedTxnCycleMax {
                state.reviewTransactionCounter = 0
                state.firedTransactionMilestones.removeAll()
                persist()
            }
            if processedReceiptCycleMax || crossedReceiptCycleMax {
                state.reviewReceiptCounter = 0
                state.firedReceiptMilestones.removeAll()
                persist()
            }
        }
    }

    private func clearOpportunity() {
        pendingReviewOpportunity = nil
    }

    private func updateActiveUsageDay(now: Date) {
        let dayKey = dayFormatter.string(from: now)
        guard state.lastActiveDay != dayKey else { return }

        if let last = state.lastActiveDay,
           let lastDate = dayFormatter.date(from: last),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)),
           calendar.isDate(lastDate, inSameDayAs: yesterday) {
            state.currentStreak += 1
        } else if state.lastActiveDay == nil {
            state.currentStreak = 1
        } else {
            state.currentStreak = 1
        }

        state.lastActiveDay = dayKey
        state.activeUsageDays += 1
    }

    private func persist() {
        store.save(state)
    }
}
