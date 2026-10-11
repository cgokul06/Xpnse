//
//  EducationEngine.swift
//  Xpnse
//

import Foundation

/// Runtime orchestrator and scheduler for the education framework.
final class EducationEngine: @unchecked Sendable {
    static let shared = EducationEngine(
        registry: EducationCampaignRegistry(campaigns: [
            IncomeSetupJourney(),
            RecurringReminderJourney(),
            ExpenseSetupJourney(),
            CustomCategoryJourney()
        ]),
        store: UserDefaultsEducationCampaignStateStore(),
        contextProvider: AppEducationEvaluationContextProvider.shared,
        policyStore: UserDefaultsEducationPolicyStateStore()
    )

    private let registry: EducationCampaignRegistry
    private let store: EducationCampaignStateStore
    private let contextProvider: EducationEvaluationContextProviding
    private let policyEngine: EducationPolicyEngine
    private let policyStore: EducationPolicyStateStore
    private let logger: EducationEngineLogging
    private let clock: Clock

    private let lock = NSLock()
    private var states: [String: CampaignState] = [:]
    private var policyStateValue: EducationPolicyState
    private var runtimeStateValue: EducationRuntimeState = .idle
    private var currentOpportunityValue: EducationOpportunity?
    private var lastEvent: EducationEvent = .appLaunched
    private var opportunityContinuations: [UUID: AsyncStream<EducationOpportunity?>.Continuation] = [:]

    init(
        registry: EducationCampaignRegistry,
        store: EducationCampaignStateStore,
        contextProvider: EducationEvaluationContextProviding,
        logger: EducationEngineLogging = NoOpEducationEngineLogger(),
        clock: Clock = SystemClock(),
        policyEngine: EducationPolicyEngine = EducationPolicyEngine(),
        policyStore: EducationPolicyStateStore = UserDefaultsEducationPolicyStateStore()
    ) {
        self.registry = registry
        self.store = store
        self.contextProvider = contextProvider
        self.policyEngine = policyEngine
        self.policyStore = policyStore
        self.logger = logger
        self.clock = clock

        let loaded = policyStore.load() ?? .fresh
        let recovered = policyEngine.clearingAbandonedSession(loaded)
        if recovered != loaded {
            policyStore.save(recovered)
        }
        self.policyStateValue = recovered

        for campaign in registry.campaigns {
            let campaignID = campaign.identity.id
            states[campaignID] = store.loadOrFresh(campaignID: campaignID)
        }
    }

    var runtimeState: EducationRuntimeState {
        lock.lock()
        defer { lock.unlock() }
        return runtimeStateValue
    }

    var activeJourneyID: String? {
        lock.lock()
        defer { lock.unlock() }
        return runtimeStateValue.activeJourneyID
    }

    var isPresentationPending: Bool {
        lock.lock()
        defer { lock.unlock() }
        return runtimeStateValue.isPresentationPending
    }

    var currentOpportunity: EducationOpportunity? {
        lock.lock()
        defer { lock.unlock() }
        return currentOpportunityValue
    }

    var policyState: EducationPolicyState {
        lock.lock()
        defer { lock.unlock() }
        return policyStateValue
    }

    func opportunityUpdates() -> AsyncStream<EducationOpportunity?> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            opportunityContinuations[id] = continuation
            let current = currentOpportunityValue
            lock.unlock()
            continuation.yield(current)

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.opportunityContinuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }

    func track(_ event: EducationEvent) {
        let yields = withLockReturningYields { continuations, yields in
            lastEvent = event
            logger.log("Event received: \(event.debugDescription)")
            policyStateValue = policyEngine.recordingUsage(
                policy: policyStateValue,
                event: event,
                now: clock.now()
            )
            persistPolicy()
            evaluateJourneysLocked(triggerEvent: event, yields: &yields)
            return continuations
        }
        flush(yields)
    }

    func evaluateJourneys() {
        let yields = withLockReturningYields { continuations, yields in
            logger.log("Evaluate journeys requested")
            evaluateJourneysLocked(triggerEvent: lastEvent, yields: &yields)
            return continuations
        }
        flush(yields)
    }

    func acceptPrimaryAction(campaignID: String) {
        lock.lock()
        defer { lock.unlock() }

        guard case .presenting(let activeID) = runtimeStateValue, activeID == campaignID else {
            logger.log("Primary action ignored for campaign: \(campaignID)")
            return
        }

        transitionLocked(to: .performingAction(journeyID: campaignID))
        transitionLocked(to: .waitingForOutcome(journeyID: campaignID))
        logger.log("Journey locked: \(campaignID)")
    }

    func applyOutcome(_ outcome: CampaignOutcome, campaignID: String) {
        let yields = withLockReturningYields { continuations, yields in
            applyOutcomeLocked(outcome, campaignID: campaignID, yields: &yields)
            return continuations
        }
        flush(yields)
    }

    // MARK: - Locked work

    private func applyOutcomeLocked(
        _ outcome: CampaignOutcome,
        campaignID: String,
        yields: inout [EducationOpportunity?]
    ) {
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
                logger.log("Journey Completed: \(campaignID) rejected")
                return
            }
            logger.log("Outcome applied for campaign \(campaignID): \(outcome.debugDescription)")
        } else {
            states[campaignID] = updatedState
            persist(updatedState)
            logger.log("Outcome applied for campaign \(campaignID): \(outcome.debugDescription)")
            if case .completed = outcome {
                logger.log("Journey Completed: \(campaignID)")
            }
        }

        lastEvent = .journeyOutcomeApplied(campaignID: campaignID)

        let isActiveJourney = runtimeStateValue.activeJourneyID == campaignID
        guard isActiveJourney || runtimeStateValue.isIdle else {
            logger.log("Evaluation skipped publish: runtime \(runtimeStateValue.debugDescription)")
            return
        }

        policyStateValue = policyEngine.endingSession(
            policy: policyStateValue,
            outcome: outcome,
            context: snapshot.campaignContext,
            now: clock.now()
        )
        persistPolicy()
        logger.log("Session Ended")
        if policyEngine.configuration.strategy(for: outcome) != EducationCooldownStrategy.none {
            logger.log("Cooldown Started")
        }

        endActiveJourneyLocked(yields: &yields)
        evaluateJourneysLocked(triggerEvent: lastEvent, yields: &yields)
    }

    private func evaluateJourneysLocked(
        triggerEvent: EducationEvent,
        yields: inout [EducationOpportunity?]
    ) {
        let snapshot = contextProvider.snapshot(for: triggerEvent, at: clock.now())
        let allStates = Array(states.values)
        var eligible: [(opportunity: EducationOpportunity, registrationIndex: Int)] = []

        for (index, campaign) in registry.campaigns.enumerated() {
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
            eligible.append((opportunity, index))
        }

        eligible.sort { lhs, rhs in
            if lhs.opportunity.priority != rhs.opportunity.priority {
                return lhs.opportunity.priority < rhs.opportunity.priority
            }
            if lhs.registrationIndex != rhs.registrationIndex {
                return lhs.registrationIndex < rhs.registrationIndex
            }
            return lhs.opportunity.campaignID < rhs.opportunity.campaignID
        }

        let winner = eligible.first?.opportunity

        guard runtimeStateValue.isIdle else {
            logger.log("Evaluation skipped publish: runtime \(runtimeStateValue.debugDescription)")
            for candidate in eligible where candidate.opportunity.campaignID != runtimeStateValue.activeJourneyID {
                logger.log("Journey deferred: \(candidate.opportunity.campaignID)")
            }
            return
        }

        guard let winner else { return }

        let decision = policyEngine.evaluate(
            policy: policyStateValue,
            runtime: runtimeStateValue,
            event: triggerEvent,
            context: snapshot.campaignContext,
            now: clock.now()
        )
        logger.log(decision.debugDescription)

        guard decision.isAllowed else {
            if case .blocked(.waitingForEvaluationTrigger) = decision {
                logger.log("Waiting For Next Trigger")
            }
            logger.log("Evaluation Deferred")
            for candidate in eligible {
                logger.log("Journey deferred: \(candidate.opportunity.campaignID)")
            }
            return
        }

        if policyStateValue.lastJourneyOutcome != nil {
            logger.log("Cooldown Ended")
        }

        publishIfNeeded(winner, yields: &yields)
    }

    private func publishIfNeeded(
        _ opportunity: EducationOpportunity?,
        yields: inout [EducationOpportunity?]
    ) {
        guard let opportunity else { return }
        guard currentOpportunityValue?.campaignID != opportunity.campaignID else { return }

        let snapshot = contextProvider.snapshot(for: lastEvent, at: clock.now())
        markCampaignPresented(opportunity.campaignID)
        currentOpportunityValue = opportunity
        policyStateValue = policyEngine.startingSession(
            policy: policyStateValue,
            journeyID: opportunity.campaignID,
            context: snapshot.campaignContext,
            now: clock.now()
        )
        persistPolicy()
        logger.log("Journey selected: \(opportunity.campaignID)")
        logger.log("Journey locked: \(opportunity.campaignID)")
        logger.log("Opportunity published: \(opportunity.campaignID)")
        logger.log("Session Started")
        transitionLocked(to: .presenting(journeyID: opportunity.campaignID))
        yields.append(opportunity)
    }

    private func endActiveJourneyLocked(yields: inout [EducationOpportunity?]) {
        let previousOpportunity = currentOpportunityValue
        currentOpportunityValue = nil
        transitionLocked(to: .idle)
        if previousOpportunity != nil {
            logger.log("Opportunity cleared")
            yields.append(nil)
        }
    }

    private func transitionLocked(to newState: EducationRuntimeState) {
        let previous = runtimeStateValue
        guard previous != newState else { return }
        runtimeStateValue = newState
        logger.log("Runtime transition: \(previous.debugDescription) -> \(newState.debugDescription)")
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

    private func persistPolicy() {
        policyStore.save(policyStateValue)
        logger.log("Policy state persisted")
    }

    private func withLockReturningYields(
        _ work: ( [AsyncStream<EducationOpportunity?>.Continuation], inout [EducationOpportunity?] ) -> [AsyncStream<EducationOpportunity?>.Continuation]
    ) -> (continuations: [AsyncStream<EducationOpportunity?>.Continuation], yields: [EducationOpportunity?]) {
        lock.lock()
        var yields: [EducationOpportunity?] = []
        let continuations = work(Array(opportunityContinuations.values), &yields)
        lock.unlock()
        return (continuations, yields)
    }

    private func flush(_ payload: (continuations: [AsyncStream<EducationOpportunity?>.Continuation], yields: [EducationOpportunity?])) {
        for value in payload.yields {
            for continuation in payload.continuations {
                continuation.yield(value)
            }
        }
    }
}

// MARK: - Debug descriptions

private extension EducationEvent {
    var debugDescription: String {
        switch self {
        case .appLaunched: return "appLaunched"
        case .appBecameActive: return "appBecameActive"
        case .transactionAdded: return "transactionAdded"
        case .expenseAdded: return "expenseAdded"
        case .incomeConfigured: return "incomeConfigured"
        case .categoryCreated: return "categoryCreated"
        case .recurringTransactionCreated: return "recurringTransactionCreated"
        case .reminderEnabled: return "reminderEnabled"
        case .notificationPermissionGranted: return "notificationPermissionGranted"
        case .widgetAdded: return "widgetAdded"
        case .returnedToHome: return "returnedToHome"
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
