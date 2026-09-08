//
//  EducationEngine.swift
//  Xpnse
//

import Foundation

/// Runtime orchestrator for the education framework.
final class EducationEngine: @unchecked Sendable {
    static let shared = EducationEngine(
        registry: EducationCampaignRegistry(campaigns: [
            IncomeSetupJourney(),
            CustomCategoryJourney()
        ]),
        store: UserDefaultsEducationCampaignStateStore(),
        contextProvider: AppEducationEvaluationContextProvider.shared
    )

    private let registry: EducationCampaignRegistry
    private let store: EducationCampaignStateStore
    private let contextProvider: EducationEvaluationContextProviding
    private let logger: EducationEngineLogging
    private let clock: Clock

    private let lock = NSLock()
    private var states: [String: CampaignState] = [:]
    private var currentOpportunityValue: EducationOpportunity?
    private var lastEvent: EducationEvent = .appLaunched
    private var opportunityContinuations: [UUID: AsyncStream<EducationOpportunity?>.Continuation] = [:]

    init(
        registry: EducationCampaignRegistry,
        store: EducationCampaignStateStore,
        contextProvider: EducationEvaluationContextProviding,
        logger: EducationEngineLogging = NoOpEducationEngineLogger(),
        clock: Clock = SystemClock()
    ) {
        self.registry = registry
        self.store = store
        self.contextProvider = contextProvider
        self.logger = logger
        self.clock = clock

        for campaign in registry.campaigns {
            let campaignID = campaign.identity.id
            states[campaignID] = store.loadOrFresh(campaignID: campaignID)
        }
    }

    var currentOpportunity: EducationOpportunity? {
        lock.lock()
        defer { lock.unlock() }
        return currentOpportunityValue
    }

    func opportunityUpdates() -> AsyncStream<EducationOpportunity?> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            opportunityContinuations[id] = continuation
            continuation.yield(currentOpportunityValue)
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.opportunityContinuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }

    func track(_ event: EducationEvent) {
        lock.lock()
        defer { lock.unlock() }
        lastEvent = event
        logger.log("Event received: \(event.debugDescription)")
        evaluateJourneysLocked(triggerEvent: event)
    }

    func evaluateJourneys() {
        lock.lock()
        defer { lock.unlock() }
        logger.log("Evaluate journeys requested")
        evaluateJourneysLocked(triggerEvent: lastEvent)
    }

    func clearCurrentOpportunity() {
        lock.lock()
        defer { lock.unlock() }
        guard currentOpportunityValue != nil else { return }
        currentOpportunityValue = nil
        logger.log("Opportunity cleared")
        for continuation in opportunityContinuations.values {
            continuation.yield(nil)
        }
    }

    func applyOutcome(_ outcome: CampaignOutcome, campaignID: String) {
        lock.lock()
        defer { lock.unlock() }

        guard let campaign = registry.campaign(id: campaignID) else {
            logger.log("Outcome ignored for unknown campaign: \(campaignID)")
            return
        }

        let snapshot = contextProvider.snapshot(for: lastEvent, at: clock.now())
        let previousState = states[campaignID] ?? store.loadOrFresh(campaignID: campaignID)
        let updatedState = campaign.applyOutcome(
            outcome,
            to: previousState,
            at: clock.now(),
            validationContext: snapshot.validationContext
        )

        if updatedState == previousState {
            if case .completed = outcome {
                logger.log("Completion validation failed for campaign: \(campaignID)")
            }
        } else {
            states[campaignID] = updatedState
            persist(updatedState)
            logger.log("Outcome applied for campaign \(campaignID): \(outcome.debugDescription)")
        }

        lastEvent = .journeyOutcomeApplied(campaignID: campaignID)
        evaluateJourneysLocked(triggerEvent: lastEvent)
    }

    // MARK: - Evaluation

    private func evaluateJourneysLocked(triggerEvent: EducationEvent) {
        let snapshot = contextProvider.snapshot(for: triggerEvent, at: clock.now())
        let allStates = Array(states.values)
        var selectedOpportunity: EducationOpportunity?

        for campaign in registry.campaigns {
            let campaignID = campaign.identity.id
            let state = states[campaignID] ?? CampaignState.fresh(campaignID: campaignID)
            let decision = campaign.evaluate(
                context: snapshot.campaignContext,
                state: state,
                allStates: allStates
            )

            logger.log("Journey evaluated \(campaignID): \(decision.debugDescription)")

            guard decision == .eligible else { continue }

            guard let opportunityCampaign = campaign as? any EducationOpportunityCampaign else {
                continue
            }

            guard let opportunity = opportunityCampaign.makeOpportunity(
                context: snapshot.campaignContext,
                state: state,
                allStates: allStates
            ) else {
                continue
            }

            logger.log("Journey eligible: \(campaignID)")
            selectedOpportunity = opportunity
            break
        }

        publishIfNeeded(selectedOpportunity)
    }

    private func publishIfNeeded(_ opportunity: EducationOpportunity?) {
        guard let opportunity else { return }
        guard currentOpportunityValue?.campaignID != opportunity.campaignID else { return }

        markCampaignPresented(opportunity.campaignID)
        currentOpportunityValue = opportunity
        logger.log("Opportunity published: \(opportunity.campaignID)")

        for continuation in opportunityContinuations.values {
            continuation.yield(opportunity)
        }
    }

    private func markCampaignPresented(_ campaignID: String) {
        let previous = states[campaignID] ?? store.loadOrFresh(campaignID: campaignID)
        let updated = CampaignStateTransition.markPresented(previous, at: clock.now())
        states[campaignID] = updated
        persist(updated)
    }

    private func persist(_ state: CampaignState) {
        store.save(state)
        logger.log("State persisted for campaign: \(state.campaignID)")
    }
}

// MARK: - Debug descriptions

private extension EducationEvent {
    var debugDescription: String {
        switch self {
        case .appLaunched: return "appLaunched"
        case .appBecameActive: return "appBecameActive"
        case .transactionAdded: return "transactionAdded"
        case .incomeConfigured: return "incomeConfigured"
        case .categoryCreated: return "categoryCreated"
        case .recurringTransactionCreated: return "recurringTransactionCreated"
        case .reminderEnabled: return "reminderEnabled"
        case .notificationPermissionGranted: return "notificationPermissionGranted"
        case .widgetAdded: return "widgetAdded"
        case .journeyOutcomeApplied(let campaignID): return "journeyOutcomeApplied(\(campaignID))"
        }
    }
}

private extension CampaignOutcome {
    var debugDescription: String {
        switch self {
        case .completed: return "completed"
        case .declined: return "declined"
        case .dismissed: return "dismissed"
        case .actionFailed: return "actionFailed"
        }
    }
}

private extension CampaignDecision {
    var debugDescription: String {
        switch self {
        case .eligible: return "eligible"
        case .notEligible(let reason): return "notEligible(\(reason))"
        }
    }
}
