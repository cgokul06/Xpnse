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
        campaignContext: CampaignContext? = nil,
        validationContext: CompletionValidationContext? = nil,
        clock: ControllableClock? = nil,
        logger: CollectingEducationEngineLogger? = nil
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
            clock: resolvedClock
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
            evaluationDate: fixedDate
        )
        let (engine, _, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney(), CustomCategoryJourney()],
            campaignContext: context
        )

        engine.track(.appLaunched)

        XCTAssertNil(engine.currentOpportunity)
        XCTAssertFalse(logger.contains("Opportunity published"))
    }

    func testSingleJourneyEligiblePublishesOpportunity() {
        let (engine, store, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            campaignContext: incomeEligibleContext()
        )

        engine.track(.appLaunched)

        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)
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

    func testDependencyFailureBlocksLowerPriorityJourney() {
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
        var completedIncome = CampaignState.fresh(campaignID: IncomeSetupJourney.campaignID)
        completedIncome.status = .completed

        let store = InMemoryEducationCampaignStateStore()
        store.save(completedIncome)

        let provider = StaticEducationEvaluationContextProvider(
            campaignContext: customCategoryEligibleContext()
        )
        let engine = EducationEngine(
            registry: EducationCampaignRegistry(campaigns: [IncomeSetupJourney(), CustomCategoryJourney()]),
            store: store,
            contextProvider: provider,
            logger: CollectingEducationEngineLogger(),
            clock: ControllableClock(now: fixedDate)
        )
        Self.retainedEngines.append(engine)

        engine.track(.transactionAdded)

        XCTAssertEqual(engine.currentOpportunity?.campaignID, CustomCategoryJourney.campaignID)
    }

    func testClearCurrentOpportunityAllowsRepublish() {
        let (engine, store, logger, _) = makeEngine(
            campaigns: [IncomeSetupJourney()],
            campaignContext: incomeEligibleContext()
        )

        engine.track(.appLaunched)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)
        XCTAssertEqual(store.load(campaignID: IncomeSetupJourney.campaignID)?.presentationCount, 1)

        engine.clearCurrentOpportunity()
        XCTAssertNil(engine.currentOpportunity)

        engine.track(.appBecameActive)
        XCTAssertEqual(engine.currentOpportunity?.campaignID, IncomeSetupJourney.campaignID)
        XCTAssertEqual(store.load(campaignID: IncomeSetupJourney.campaignID)?.presentationCount, 2)
        XCTAssertEqual(
            logger.recordedMessages().filter { $0.contains("Opportunity published") }.count,
            2
        )
    }
}
