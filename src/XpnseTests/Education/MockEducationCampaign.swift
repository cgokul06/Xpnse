//
//  MockEducationCampaign.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

/// Test double for `EducationCampaign` with configurable evaluation behavior.
struct MockEducationCampaign: EducationCampaign {
    let identity: EducationCampaignIdentity
    let decision: CampaignDecision
    let campaignPrerequisites: [JourneyPrerequisite]
    let customEvaluateFeature: ((CampaignContext, CampaignState) -> CampaignDecision)?

    init(
        id: String = "mock_campaign",
        name: String = "Mock Campaign",
        priority: Int = 100,
        decision: CampaignDecision = .eligible,
        prerequisites: [JourneyPrerequisite] = [],
        customEvaluateFeature: ((CampaignContext, CampaignState) -> CampaignDecision)? = nil
    ) {
        self.identity = EducationCampaignIdentity(id: id, name: name, priority: priority)
        self.decision = decision
        self.campaignPrerequisites = prerequisites
        self.customEvaluateFeature = customEvaluateFeature
    }

    var prerequisites: [JourneyPrerequisite] {
        campaignPrerequisites
    }

    func evaluateFeatureEligibility(context: CampaignContext, state: CampaignState) -> CampaignDecision {
        if let customEvaluateFeature {
            return customEvaluateFeature(context, state)
        }
        return decision
    }
}

/// Test double that can produce opportunities when eligible.
struct MockEducationOpportunityCampaign: EducationOpportunityCampaign {
    let identity: EducationCampaignIdentity
    let decision: CampaignDecision
    let campaignPrerequisites: [JourneyPrerequisite]

    init(
        id: String,
        name: String = "Mock Opportunity Campaign",
        priority: Int = 100,
        decision: CampaignDecision = .eligible,
        prerequisites: [JourneyPrerequisite] = []
    ) {
        self.identity = EducationCampaignIdentity(id: id, name: name, priority: priority)
        self.decision = decision
        self.campaignPrerequisites = prerequisites
    }

    var prerequisites: [JourneyPrerequisite] {
        campaignPrerequisites
    }

    func evaluateFeatureEligibility(context: CampaignContext, state: CampaignState) -> CampaignDecision {
        decision
    }

    func buildOpportunity(context: CampaignContext, state: CampaignState) -> EducationOpportunity {
        EducationOpportunity(
            campaignID: identity.id,
            priority: identity.priority,
            sheetModel: EducationSheetModel(
                id: "\(identity.id)_sheet",
                title: identity.name,
                description: "Test opportunity",
                primaryButton: EducationSheetButtonModel(id: "primary", title: "Go")
            ),
            primaryAction: .openAddTransaction(.incomeSetupDefault)
        )
    }
}

/// Class mock so eligibility can change after the engine has been constructed.
final class MutableMockEducationOpportunityCampaign: EducationOpportunityCampaign, @unchecked Sendable {
    let identity: EducationCampaignIdentity
    var decision: CampaignDecision
    let campaignPrerequisites: [JourneyPrerequisite]

    init(
        id: String,
        name: String = "Mutable Mock Opportunity Campaign",
        priority: Int = 100,
        decision: CampaignDecision = .eligible,
        prerequisites: [JourneyPrerequisite] = []
    ) {
        self.identity = EducationCampaignIdentity(id: id, name: name, priority: priority)
        self.decision = decision
        self.campaignPrerequisites = prerequisites
    }

    var prerequisites: [JourneyPrerequisite] {
        campaignPrerequisites
    }

    func evaluateFeatureEligibility(context: CampaignContext, state: CampaignState) -> CampaignDecision {
        decision
    }

    func buildOpportunity(context: CampaignContext, state: CampaignState) -> EducationOpportunity {
        EducationOpportunity(
            campaignID: identity.id,
            priority: identity.priority,
            sheetModel: EducationSheetModel(
                id: "\(identity.id)_sheet",
                title: identity.name,
                description: "Test opportunity",
                primaryButton: EducationSheetButtonModel(id: "primary", title: "Go")
            ),
            primaryAction: .openAddTransaction(.incomeSetupDefault)
        )
    }
}

/// In-memory store for unit tests only.
final class InMemoryEducationCampaignStateStore: EducationCampaignStateStore, @unchecked Sendable {
    private var states: [String: CampaignState] = [:]
    private let lock = NSLock()

    func load(campaignID: String) -> CampaignState? {
        lock.lock()
        defer { lock.unlock() }
        return states[campaignID]
    }

    func save(_ state: CampaignState) {
        lock.lock()
        defer { lock.unlock() }
        states[state.campaignID] = state
    }
}

/// In-memory global policy store for unit tests only.
final class InMemoryEducationPolicyStateStore: EducationPolicyStateStore, @unchecked Sendable {
    private var state: EducationPolicyState?
    private let lock = NSLock()

    init(state: EducationPolicyState? = nil) {
        self.state = state
    }

    func load() -> EducationPolicyState? {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    func save(_ state: EducationPolicyState) {
        lock.lock()
        defer { lock.unlock() }
        self.state = state
    }
}

final class MockEducationCampaignTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    private lazy var context = CampaignContext(evaluationDate: fixedDate)

    func testEvaluateIsDeterministic() {
        let campaign = MockEducationCampaign(decision: .eligible)
        let state = CampaignState.fresh(campaignID: "mock_campaign")

        let first = campaign.evaluate(context: context, state: state, allStates: [state])
        let second = campaign.evaluate(context: context, state: state, allStates: [state])

        XCTAssertEqual(first, second)
        XCTAssertEqual(first, .eligible)
    }

    func testTerminalGuardBlocksCompletedState() {
        var state = CampaignState.fresh(campaignID: "mock_campaign")
        state.status = .completed

        let campaign = MockEducationCampaign(decision: .eligible)
        let result = campaign.evaluate(context: context, state: state, allStates: [state])

        XCTAssertEqual(result, .notEligible(.alreadyCompleted))
    }

    func testTerminalGuardBlocksDeclinedState() {
        var state = CampaignState.fresh(campaignID: "mock_campaign")
        state.status = .declined

        let campaign = MockEducationCampaign(decision: .eligible)
        let result = campaign.evaluate(context: context, state: state, allStates: [state])

        XCTAssertEqual(result, .notEligible(.alreadyDeclined))
    }

    func testPresentedStateCanStillEvaluateEligible() {
        var state = CampaignState.fresh(campaignID: "mock_campaign")
        state.status = .presented
        state.dismissedCount = 2

        let campaign = MockEducationCampaign(decision: .eligible)
        let result = campaign.evaluate(context: context, state: state, allStates: [state])

        XCTAssertEqual(result, .eligible)
    }

    func testCustomEvaluateOverridesDefaultDecision() {
        let campaign = MockEducationCampaign(
            decision: .eligible,
            customEvaluateFeature: { _, _ in .notEligible(.tooFewTransactions) }
        )
        let state = CampaignState.fresh(campaignID: "mock_campaign")

        XCTAssertEqual(
            campaign.evaluate(context: context, state: state, allStates: [state]),
            .notEligible(.tooFewTransactions)
        )
    }

    func testLoadOrFreshReturnsFreshWhenMissing() {
        let store = InMemoryEducationCampaignStateStore()
        let loaded = store.loadOrFresh(campaignID: "new_campaign")

        XCTAssertEqual(loaded.campaignID, "new_campaign")
        XCTAssertEqual(loaded.status, .notStarted)
        XCTAssertEqual(loaded.presentationCount, 0)
    }

    func testStoreRoundTrip() {
        let store = InMemoryEducationCampaignStateStore()
        var state = CampaignState.fresh(campaignID: "stored")
        state = CampaignStateTransition.markPresented(state, at: fixedDate)
        store.save(state)

        let loaded = store.load(campaignID: "stored")
        XCTAssertEqual(loaded, state)
    }
}
