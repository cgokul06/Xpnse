//
//  EducationEngineTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

@MainActor
final class EducationEngineTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// Retain engines for the suite lifetime to avoid MainActor deinit crashes.
    private static var retainedEngines: [EducationEngine] = []

    private func makeEngine(
        campaigns: [any EducationCampaign],
        store: InMemoryEducationCampaignStateStore = InMemoryEducationCampaignStateStore(),
        policyStore: InMemoryEducationPolicyStateStore = InMemoryEducationPolicyStateStore(),
        campaignContext: CampaignContext? = nil,
        validationContext: CompletionValidationContext? = nil,
        clock: ControllableClock? = nil,
        logger: CollectingEducationEngineLogger? = nil,
        policyEngine: EducationPolicyEngine = EducationPolicyEngine()
    ) -> (
        engine: EducationEngine,
        store: InMemoryEducationCampaignStateStore,
        logger: CollectingEducationEngineLogger,
        clock: ControllableClock
    ) {
        let resolvedClock = clock ?? ControllableClock(now: fixedDate)
        let resolvedLogger = logger ?? CollectingEducationEngineLogger()
        let context = campaignContext ?? CampaignContext(evaluationDate: fixedDate)
        let provider = StaticEducationEvaluationContextProvider(
            campaignContext: context,
            validationContext: validationContext
        )
        let engine = EducationEngine(
            registry: EducationCampaignRegistry(campaigns: campaigns),
            store: store,
            contextProvider: provider,
            logger: resolvedLogger,
            clock: resolvedClock,
            policyEngine: policyEngine,
            policyStore: policyStore
        )
        Self.retainedEngines.append(engine)
        return (engine, store, resolvedLogger, resolvedClock)
    }

    private func incomeEligibleContext() -> CampaignContext {
        CampaignContext(evaluationDate: fixedDate)
    }

    private func customCategoryEligibleContext() -> CampaignContext {
        CampaignContext(
            transactionCount: CustomCategoryJourney.minimumTransactionCount,
            evaluationDate: fixedDate
        )
    }

    // MARK: - Evaluation

    func testNoJourneysEligibleLeavesOpportunityNil() {
        let context = CampaignContext(
            transactionCount: CustomCategoryJourney.minimumTransactionCount,
            hasConfiguredIncome: true,
            customCategoryCount: 1,
            evaluationDate: fixedDate
        )
        let (engine, _, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney(), CustomCategoryJourney()],
            campaignContext: context
        )

        engine.track(.appLaunched)

        XCTAssertNil(engine.currentOpportunity)
        XCTAssertEqual(engine.runtimeState, .idle)
        XCTAssertNil(engine.activeJourneyID)
        XCTAssertFalse(engine.isPresentationPending)
        XCTAssertFalse(logger.contains("Opportunity published"))
    }

    func testSingleJourneyEligiblePublishesOpportunity() {
        let (engine, store, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            campaignContext: incomeEligibleContext()
        )

        engine.track(.appLaunched)

        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)
        XCTAssertEqual(engine.runtimeState, .presenting(journeyID: IncomeSetupJourney.campaignID))
        XCTAssertEqual(engine.activeJourneyID, IncomeSetupJourney.campaignID)
        XCTAssertTrue(engine.isPresentationPending)
        XCTAssertTrue(logger.contains("Opportunity published: income_setup"))

        let persisted = store.load(campaignID: IncomeSetupJourney.campaignID)
        XCTAssertEqual(persisted?.status, .presented)
        XCTAssertEqual(persisted?.presentationCount, 1)
    }

    func testMultipleEligibleJourneysSelectHighestPriority() {
        let highPriority = MockEducationOpportunityCampaign(id: "high_priority", priority: 0, decision: .eligible)
        let lowPriority = MockEducationOpportunityCampaign(id: "low_priority", priority: 10, decision: .eligible)
        let (engine, _, _, _) = makeEngine(campaigns: [highPriority, lowPriority])

        engine.track(.appLaunched)

        XCTAssertEqual(engine.currentOpportunity?.campaignID, "high_priority")
    }

    func testEqualPriorityTieBreakUsesRegistrationOrder() {
        let first = MockEducationOpportunityCampaign(id: "first", priority: 5, decision: .eligible)
        let second = MockEducationOpportunityCampaign(id: "second", priority: 5, decision: .eligible)
        let (engine, _, _, _) = makeEngine(campaigns: [first, second])

        engine.track(.appLaunched)

        XCTAssertEqual(engine.currentOpportunity?.campaignID, "first")
    }

    func testEqualPriorityRegistrationOrderBeatsCampaignID() {
        let zeta = MockEducationOpportunityCampaign(id: "zeta", priority: 5, decision: .eligible)
        let alpha = MockEducationOpportunityCampaign(id: "alpha", priority: 5, decision: .eligible)
        let (engine, _, _, _) = makeEngine(campaigns: [zeta, alpha])

        engine.track(.appLaunched)

        XCTAssertEqual(engine.currentOpportunity?.campaignID, "zeta")
    }

    func testLosersAreNotMarkedPresented() {
        let highPriority = MockEducationOpportunityCampaign(id: "high_priority", priority: 0, decision: .eligible)
        let lowPriority = MockEducationOpportunityCampaign(id: "low_priority", priority: 10, decision: .eligible)
        let (engine, store, _, _) = makeEngine(campaigns: [highPriority, lowPriority])

        engine.track(.appLaunched)

        XCTAssertEqual(store.load(campaignID: "high_priority")?.presentationCount, 1)
        XCTAssertEqual(store.load(campaignID: "low_priority")?.status, .notStarted)
        XCTAssertEqual(store.load(campaignID: "low_priority")?.presentationCount, 0)
    }

    func testStickyLockDoesNotReplacePublishedJourney() {
        let locked = MutableMockEducationOpportunityCampaign(id: "locked", priority: 10, decision: .eligible)
        let usurper = MutableMockEducationOpportunityCampaign(
            id: "usurper",
            priority: 0,
            decision: .notEligible(.tooFewTransactions)
        )
        let (engine, _, logger, _) = makeEngine(campaigns: [locked, usurper])

        engine.track(.appLaunched)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, "locked")

        usurper.decision = .eligible
        engine.track(.appBecameActive)

        XCTAssertEqual(engine.currentOpportunity?.campaignID, "locked")
        XCTAssertEqual(engine.runtimeState, .presenting(journeyID: "locked"))
        XCTAssertTrue(logger.contains("Evaluation skipped publish"))
        XCTAssertTrue(logger.contains("Journey deferred: usurper"))
    }

    func testIncomeSetupWinsWhenCustomCategoryHasTooFewTransactions() {
        let (engine, _, _, _) = makeEngine(
            campaigns: [IncomeSetupJourney(), CustomCategoryJourney()],
            campaignContext: incomeEligibleContext()
        )

        engine.track(.appLaunched)

        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)
        XCTAssertNotEqual(engine.currentOpportunity?.campaignID, CustomCategoryJourney.campaignID)
    }

    func testExistingTransactionsDoNotPublishIncomeSetup() {
        let (engine, _, _, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            campaignContext: CampaignContext(
                transactionCount: 1,
                evaluationDate: fixedDate
            )
        )

        engine.track(.appLaunched)

        XCTAssertNil(engine.currentOpportunity)
    }

    func testRepeatedEvaluationIsIdempotent() {
        let (engine, store, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            campaignContext: incomeEligibleContext()
        )

        engine.track(.appLaunched)
        engine.track(.appBecameActive)

        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)
        XCTAssertEqual(
            logger.recordedMessages().filter { $0.contains("Opportunity published") }.count,
            1
        )
        XCTAssertEqual(store.load(campaignID: IncomeSetupJourney.campaignID)?.presentationCount, 1)
    }

    func testEvaluateJourneysWithoutNewEvent() {
        let (engine, _, _, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            campaignContext: incomeEligibleContext()
        )

        engine.evaluateJourneys()

        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)
    }

    // MARK: - Outcomes

    func testCompletedOutcomeUpdatesStateWhenValidationPasses() {
        let testStore = InMemoryEducationCampaignStateStore()
        let (engine, _, _, clock) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            store: testStore,
            campaignContext: incomeEligibleContext(),
            validationContext: CompletionValidationContext(hasConfiguredIncome: true)
        )

        engine.track(.appLaunched)
        engine.applyOutcome(.completed, campaignID: IncomeSetupJourney.campaignID)

        let state = testStore.load(campaignID: IncomeSetupJourney.campaignID)
        XCTAssertEqual(state?.status, .completed)
        XCTAssertEqual(state?.completedDate, clock.now())
        XCTAssertNil(engine.currentOpportunity)
        XCTAssertEqual(engine.runtimeState, .idle)
    }

    func testDeclinedOutcomeUpdatesState() {
        let testStore = InMemoryEducationCampaignStateStore()
        let (engine, _, _, clock) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            store: testStore,
            campaignContext: incomeEligibleContext()
        )

        engine.track(.appLaunched)
        engine.applyOutcome(.declined, campaignID: IncomeSetupJourney.campaignID)

        let state = testStore.load(campaignID: IncomeSetupJourney.campaignID)
        XCTAssertEqual(state?.status, .declined)
        XCTAssertEqual(state?.declinedDate, clock.now())
        XCTAssertNil(engine.currentOpportunity)
        XCTAssertEqual(engine.runtimeState, .idle)
    }

    func testDismissedOutcomeIncrementsDismissedCount() {
        let testStore = InMemoryEducationCampaignStateStore()
        let (engine, _, _, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            store: testStore,
            campaignContext: incomeEligibleContext()
        )

        engine.track(.appLaunched)
        engine.applyOutcome(.dismissed, campaignID: IncomeSetupJourney.campaignID)

        let state = testStore.load(campaignID: IncomeSetupJourney.campaignID)
        XCTAssertEqual(state?.status, .presented)
        XCTAssertEqual(state?.dismissedCount, 1)
        XCTAssertEqual(state?.presentationCount, 1)
        XCTAssertNil(engine.currentOpportunity)
        XCTAssertEqual(engine.runtimeState, .idle)
        XCTAssertTrue(engine.policyState.awaitingEvaluationTrigger)
    }

    func testCompletionValidationFailureLeavesStateUnchanged() {
        let testStore = InMemoryEducationCampaignStateStore()
        let testLogger = CollectingEducationEngineLogger()
        let (engine, _, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            store: testStore,
            campaignContext: incomeEligibleContext(),
            validationContext: CompletionValidationContext(hasConfiguredIncome: false),
            logger: testLogger
        )

        engine.track(.appLaunched)
        let presented = testStore.load(campaignID: IncomeSetupJourney.campaignID)
        engine.applyOutcome(.completed, campaignID: IncomeSetupJourney.campaignID)

        XCTAssertEqual(testStore.load(campaignID: IncomeSetupJourney.campaignID), presented)
        XCTAssertTrue(logger.contains("Completion validation failed"))
    }

    func testUnknownCampaignOutcomeIsIgnored() {
        let (engine, _, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            campaignContext: incomeEligibleContext()
        )

        engine.applyOutcome(.completed, campaignID: "unknown_campaign")

        XCTAssertTrue(logger.contains("Outcome ignored for unknown campaign"))
    }

    // MARK: - Streams and concurrency

    func testOpportunityUpdatesStreamReceivesPublishedOpportunity() async {
        let (engine, _, _, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            campaignContext: incomeEligibleContext()
        )

        let stream = engine.opportunityUpdates()
        var iterator = stream.makeAsyncIterator()

        if case .some(let initialOpportunity) = await iterator.next() {
            XCTAssertNil(initialOpportunity)
        } else {
            XCTFail("Expected initial stream yield")
        }

        engine.track(.appLaunched)

        if case .some(let publishedOpportunity) = await iterator.next() {
            XCTAssertEqual(publishedOpportunity?.campaignID, IncomeSetupJourney.campaignID)
        } else {
            XCTFail("Expected published opportunity")
        }
    }

    func testConcurrentEventsProduceDeterministicFinalState() {
        let testStore = InMemoryEducationCampaignStateStore()
        let (engine, _, _, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            store: testStore,
            campaignContext: incomeEligibleContext()
        )

        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            engine.track(.appLaunched)
        }

        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)
        XCTAssertEqual(testStore.load(campaignID: IncomeSetupJourney.campaignID)?.presentationCount, 1)
    }

    func testCustomCategoryEligibleAfterIncomeCompleted() {
        XCTAssertEqual(
            publishCustomCategory(incomeStatus: .completed)?.campaignID,
            CustomCategoryJourney.campaignID
        )
    }

    func testCustomCategoryEligibleAfterIncomeDeclined() {
        XCTAssertEqual(
            publishCustomCategory(incomeStatus: .declined)?.campaignID,
            CustomCategoryJourney.campaignID
        )
    }

    func testCustomCategoryEligibleWhenIncomeSetupNeverStarted() {
        XCTAssertEqual(
            publishCustomCategory(incomeStatus: .notStarted)?.campaignID,
            CustomCategoryJourney.campaignID
        )
    }

    private func publishCustomCategory(incomeStatus: CampaignStatus) -> EducationOpportunity? {
        var income = CampaignState.fresh(campaignID: IncomeSetupJourney.campaignID)
        income.status = incomeStatus

        let store = InMemoryEducationCampaignStateStore()
        store.save(income)

        let provider = StaticEducationEvaluationContextProvider(
            campaignContext: customCategoryEligibleContext()
        )
        let engine = EducationEngine(
            registry: EducationCampaignRegistry(campaigns: [IncomeSetupJourney(), CustomCategoryJourney()]),
            store: store,
            contextProvider: provider,
            logger: CollectingEducationEngineLogger(),
            clock: ControllableClock(now: fixedDate),
            policyStore: InMemoryEducationPolicyStateStore()
        )
        Self.retainedEngines.append(engine)
        engine.track(.transactionAdded)
        return engine.currentOpportunity
    }

    func testDismissedOutcomeWaitsForNextTriggerBeforeRepublish() {
        let (engine, store, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            campaignContext: incomeEligibleContext()
        )

        engine.track(.appLaunched)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)
        XCTAssertEqual(store.load(campaignID: IncomeSetupJourney.campaignID)?.presentationCount, 1)

        engine.applyOutcome(.dismissed, campaignID: IncomeSetupJourney.campaignID)
        XCTAssertNil(engine.currentOpportunity)
        XCTAssertEqual(engine.runtimeState, .idle)
        XCTAssertTrue(logger.contains("Waiting For Next Trigger"))

        engine.track(.appBecameActive)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)
        XCTAssertEqual(store.load(campaignID: IncomeSetupJourney.campaignID)?.presentationCount, 2)
        XCTAssertEqual(
            logger.recordedMessages().filter { $0.contains("Opportunity published") }.count,
            2
        )
    }

    func testExpensePublishesOnReturnedToHomeAfterIncomeCompleted() {
        let (engine, _, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney(), ExpenseSetupJourney()],
            campaignContext: incomeEligibleContext(),
            validationContext: CompletionValidationContext(hasConfiguredIncome: true)
        )

        engine.track(.appLaunched)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)

        engine.applyOutcome(.completed, campaignID: IncomeSetupJourney.campaignID)
        XCTAssertNil(engine.currentOpportunity)
        XCTAssertTrue(logger.contains("Evaluation Deferred") || logger.contains("Waiting For Next Trigger"))

        engine.track(.returnedToHome)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, ExpenseSetupJourney.campaignID)
    }

    func testExpenseWaitsForNextForegroundAfterIncomeDeclined() {
        let clock = ControllableClock(now: fixedDate)
        let (engine, _, _, _) = makeEngine(
            campaigns: [IncomeSetupJourney(), ExpenseSetupJourney()],
            campaignContext: incomeEligibleContext(),
            clock: clock
        )

        engine.track(.appLaunched)
        engine.applyOutcome(.declined, campaignID: IncomeSetupJourney.campaignID)
        XCTAssertNil(engine.currentOpportunity)

        engine.track(.returnedToHome)
        XCTAssertNil(engine.currentOpportunity)

        engine.track(.appBecameActive)
        XCTAssertNil(engine.currentOpportunity)

        clock.advance(by: EducationPolicyConfiguration.defaultDeclineMinimumElapsedTime)
        engine.track(.appBecameActive)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, ExpenseSetupJourney.campaignID)
    }

    func testExpenseWaitsForNextLaunchAfterIncomeDismissedAsDeclined() {
        let clock = ControllableClock(now: fixedDate)
        let (engine, _, _, _) = makeEngine(
            campaigns: [IncomeSetupJourney(), ExpenseSetupJourney()],
            campaignContext: incomeEligibleContext(),
            clock: clock
        )

        engine.track(.appLaunched)
        engine.applyOutcome(.declined, campaignID: IncomeSetupJourney.campaignID)
        engine.track(.returnedToHome)
        XCTAssertNil(engine.currentOpportunity)

        clock.advance(by: EducationPolicyConfiguration.defaultDeclineMinimumElapsedTime)
        engine.track(.appLaunched)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, ExpenseSetupJourney.campaignID)
    }

    func testExpenseDoesNotPublishWhenExpenseAlreadyExists() {
        var income = CampaignState.fresh(campaignID: IncomeSetupJourney.campaignID)
        income.status = .declined
        let store = InMemoryEducationCampaignStateStore()
        store.save(income)

        let (engine, _, _, _) = makeEngine(
            campaigns: [IncomeSetupJourney(), ExpenseSetupJourney()],
            store: store,
            campaignContext: CampaignContext(
                transactionCount: 1,
                expenseCount: 1,
                evaluationDate: fixedDate
            )
        )

        engine.track(.appLaunched)
        XCTAssertNil(engine.currentOpportunity)
    }

    func testReminderPublishesWhenFirstRecurringCreatedWithoutNotify() {
        let (engine, _, _, _) = makeEngine(
            campaigns: [RecurringReminderJourney()],
            campaignContext: CampaignContext(
                recurringTransactionCount: 1,
                notificationAuthorizationStatus: .notDetermined,
                evaluationDate: fixedDate
            )
        )

        engine.track(.recurringTransactionCreated)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, RecurringReminderJourney.campaignID)
    }

    func testReminderDoesNotPublishWhenNotificationAlreadyGranted() {
        let (engine, _, _, _) = makeEngine(
            campaigns: [RecurringReminderJourney()],
            campaignContext: CampaignContext(
                recurringTransactionCount: 1,
                notificationAuthorizationStatus: .authorized,
                evaluationDate: fixedDate
            )
        )

        engine.track(.recurringTransactionCreated)
        XCTAssertNil(engine.currentOpportunity)
    }

    func testReminderDoesNotPublishWhenNotificationDenied() {
        let (engine, _, _, _) = makeEngine(
            campaigns: [RecurringReminderJourney()],
            campaignContext: CampaignContext(
                recurringTransactionCount: 1,
                notificationAuthorizationStatus: .denied,
                evaluationDate: fixedDate
            )
        )

        engine.track(.recurringTransactionCreated)
        XCTAssertNil(engine.currentOpportunity)
    }

    func testExpenseDoesNotPublishBeforeIncomeIsActedOn() {
        let (engine, _, _, _) = makeEngine(
            campaigns: [ExpenseSetupJourney()],
            campaignContext: incomeEligibleContext()
        )

        engine.track(.appLaunched)
        XCTAssertNil(engine.currentOpportunity)
    }

    func testCompletedOutcomeDoesNotImmediatelyPublishNextJourney() {
        let next = MockEducationOpportunityCampaign(id: "next_journey", priority: 20, decision: .eligible)
        let (engine, _, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney(), next],
            campaignContext: incomeEligibleContext(),
            validationContext: CompletionValidationContext(hasConfiguredIncome: true)
        )

        engine.track(.appLaunched)
        engine.applyOutcome(.completed, campaignID: IncomeSetupJourney.campaignID)

        XCTAssertNil(engine.currentOpportunity)
        XCTAssertEqual(engine.runtimeState, .idle)
        XCTAssertTrue(logger.contains("Evaluation Deferred"))
        XCTAssertTrue(logger.contains("Journey deferred: next_journey"))

        engine.track(.appBecameActive)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, "next_journey")
    }

    func testDeclinedOutcomeBlocksUntilElapsedTimeAndTrigger() {
        let next = MockEducationOpportunityCampaign(id: "next_journey", priority: 20, decision: .eligible)
        let clock = ControllableClock(now: fixedDate)
        let (engine, _, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney(), next],
            campaignContext: incomeEligibleContext(),
            clock: clock
        )

        engine.track(.appLaunched)
        engine.applyOutcome(.declined, campaignID: IncomeSetupJourney.campaignID)
        XCTAssertNil(engine.currentOpportunity)
        XCTAssertTrue(logger.contains("Decline Cooldown") || logger.contains("Waiting For Next Trigger"))

        engine.track(.appBecameActive)
        XCTAssertNil(engine.currentOpportunity)
        XCTAssertTrue(logger.contains("Decline Cooldown"))

        clock.advance(by: EducationPolicyConfiguration.defaultDeclineMinimumElapsedTime)
        engine.track(.appBecameActive)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, "next_journey")
        XCTAssertTrue(logger.contains("Cooldown Ended"))
    }

    func testActionFailedWaitsForNextTriggerBeforeRepublish() {
        let (engine, store, _, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            campaignContext: incomeEligibleContext()
        )

        engine.track(.appLaunched)
        engine.acceptPrimaryAction(campaignID: IncomeSetupJourney.campaignID)
        engine.applyOutcome(.actionFailed, campaignID: IncomeSetupJourney.campaignID)

        XCTAssertNil(engine.currentOpportunity)
        XCTAssertEqual(store.load(campaignID: IncomeSetupJourney.campaignID)?.presentationCount, 1)

        engine.track(.appBecameActive)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)
        XCTAssertEqual(store.load(campaignID: IncomeSetupJourney.campaignID)?.presentationCount, 2)
    }

    func testPolicyBlocksMultipleEligibleJourneysAfterDecline() {
        let first = MockEducationOpportunityCampaign(id: "first", priority: 0, decision: .eligible)
        let second = MockEducationOpportunityCampaign(id: "second", priority: 10, decision: .eligible)
        let (engine, store, _, _) = makeEngine(campaigns: [first, second])

        engine.track(.appLaunched)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, "first")
        engine.applyOutcome(.declined, campaignID: "first")

        XCTAssertNil(engine.currentOpportunity)
        XCTAssertEqual(store.load(campaignID: "second")?.presentationCount ?? 0, 0)
        XCTAssertEqual(engine.policyState.lastJourneyOutcome, .declined)
        XCTAssertTrue(engine.policyState.awaitingEvaluationTrigger)
        XCTAssertFalse(engine.policyState.sessionActive)
    }

    func testPresentedJourneyStartsEducationSession() {
        let (engine, _, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            campaignContext: incomeEligibleContext()
        )

        engine.track(.appLaunched)

        XCTAssertTrue(engine.policyState.sessionActive)
        XCTAssertEqual(engine.policyState.lastPresentedJourneyID, IncomeSetupJourney.campaignID)
        XCTAssertNotNil(engine.policyState.currentSessionID)
        XCTAssertTrue(logger.contains("Session Started"))
    }

    func testPolicyStatePersistsAcrossEngineInstances() {
        let policyStore = InMemoryEducationPolicyStateStore()
        let campaignStore = InMemoryEducationCampaignStateStore()
        let (firstEngine, _, _, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            store: campaignStore,
            policyStore: policyStore,
            campaignContext: incomeEligibleContext()
        )

        firstEngine.track(.appLaunched)
        firstEngine.applyOutcome(.declined, campaignID: IncomeSetupJourney.campaignID)

        let (secondEngine, _, _, _) = makeEngine(
            campaigns: [MockEducationOpportunityCampaign(id: "follow_up", priority: 5, decision: .eligible)],
            store: InMemoryEducationCampaignStateStore(),
            policyStore: policyStore,
            campaignContext: incomeEligibleContext()
        )

        secondEngine.track(.appBecameActive)
        XCTAssertNil(secondEngine.currentOpportunity)
        XCTAssertEqual(secondEngine.policyState.lastJourneyOutcome, .declined)
    }
}
