//
//  UserEngagementCoordinator.swift
//  Xpnse
//

import Foundation
import Observation

/// Bridge between `UserSatisfactionEngine` and SwiftUI.
/// Owns presentation timing, queuing, and which engagement UI is visible.
@Observable
@MainActor
final class UserEngagementCoordinator {
    static let shared = UserEngagementCoordinator()

    static let requiredContinuousUsageSeconds: TimeInterval = 60

    /// Currently visible engagement experience (drives the sheet).
    private(set) var presentedEngagement: EngagementPresentation?

    @ObservationIgnored private weak var engine: UserSatisfactionEngine?
    @ObservationIgnored private var queuedOpportunities: [ReviewOpportunity] = []
    @ObservationIgnored private var busyReasons: Set<BusyWorkReason> = []
    @ObservationIgnored private var hasSettledPastLaunch = false
    @ObservationIgnored private var isForegroundActive = false
    @ObservationIgnored private var continuousForegroundStartedAt: Date?
    @ObservationIgnored private var observedOpportunityID: UUID?
    @ObservationIgnored private let clock: Clock

    init(clock: Clock = SystemClock()) {
        self.clock = clock
    }

    // MARK: - Binding

    func attach(engine: UserSatisfactionEngine = .shared) {
        self.engine = engine
        reconcile()
    }

    /// Call from the host periodically and when engine state may have changed.
    func reconcile() {
        guard let engine else { return }

        if let opportunity = engine.pendingReviewOpportunity,
           opportunity.id != observedOpportunityID {
            observedOpportunityID = opportunity.id
            enqueue(opportunity)
        }

        if engine.pendingReviewOpportunity == nil {
            observedOpportunityID = nil
            // Drop queued items that are no longer pending on the engine.
            queuedOpportunities.removeAll()
            if presentedEngagement != nil {
                // Engine cleared while sheet still open (e.g. outcome already reported).
                presentedEngagement = nil
            }
        }

        tryPresentNext()
    }

    // MARK: - Presentation gates (moved out of the engine)

    func markSettledPastLaunch() {
        guard !hasSettledPastLaunch else { return }
        hasSettledPastLaunch = true
        if isForegroundActive {
            continuousForegroundStartedAt = clock.now()
        }
        tryPresentNext()
    }

    func noteAppBecameActive() {
        isForegroundActive = true
        if hasSettledPastLaunch {
            continuousForegroundStartedAt = clock.now()
        }
        tryPresentNext()
    }

    func noteAppEnteredBackground() {
        isForegroundActive = false
        continuousForegroundStartedAt = nil
    }

    func beginBusyWork(_ reason: BusyWorkReason) {
        busyReasons.insert(reason)
    }

    func endBusyWork(_ reason: BusyWorkReason) {
        busyReasons.remove(reason)
        tryPresentNext()
    }

    func checkPresentationGate() {
        tryPresentNext()
    }

    // MARK: - Outcomes from UI

    func dismissCurrentEngagement(reportToEngine: Bool = true) {
        guard presentedEngagement != nil else { return }
        if reportToEngine {
            engine?.track(.reviewPromptDismissed)
        }
        presentedEngagement = nil
        tryPresentNext()
    }

    func reportAppStoreReviewOpened() {
        engine?.track(.appStoreReviewOpened)
        presentedEngagement = nil
    }

    func reportFeedbackSubmitted() {
        engine?.track(.feedbackSubmitted)
        presentedEngagement = nil
    }

    func reportFeedbackCancelled() {
        engine?.track(.reviewPromptDismissed)
        presentedEngagement = nil
        tryPresentNext()
    }

    // MARK: - Internals

    private func enqueue(_ opportunity: ReviewOpportunity) {
        if presentedEngagement?.id == opportunity.id { return }
        if queuedOpportunities.contains(where: { $0.id == opportunity.id }) { return }
        queuedOpportunities.append(opportunity)
        queuedOpportunities.sort { $0.priority < $1.priority }
    }

    private func tryPresentNext() {
        guard presentedEngagement == nil else { return }
        guard canPresentEngagement else { return }
        guard !queuedOpportunities.isEmpty else { return }

        let next = queuedOpportunities.removeFirst()
        presentedEngagement = .appReview(next)
        analyticsPresented()
    }

    private var canPresentEngagement: Bool {
        guard hasSettledPastLaunch else { return false }
        guard isForegroundActive else { return false }
        guard busyReasons.isEmpty else { return false }
        guard let started = continuousForegroundStartedAt else {
            continuousForegroundStartedAt = clock.now()
            return false
        }
        return clock.now().timeIntervalSince(started) >= Self.requiredContinuousUsageSeconds
    }

    private func analyticsPresented() {
        AppAnalytics.logEvent(AppAnalytics.Event.reviewFeedbackFlowPresented)
    }
}
