//
//  EducationCampaignRegistryTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class EducationCampaignRegistryTests: XCTestCase {
    func testCampaignsSortedByPriorityAscending() {
        let low = MockEducationCampaign(id: "low", priority: 10)
        let high = MockEducationCampaign(id: "high", priority: 1)
        let mid = MockEducationCampaign(id: "mid", priority: 5)

        let registry = EducationCampaignRegistry(campaigns: [low, high, mid])

        XCTAssertEqual(registry.campaigns.map(\.identity.id), ["high", "mid", "low"])
    }

    func testEqualPriorityPreservesRegistrationOrder() {
        let zeta = MockEducationCampaign(id: "zeta", priority: 5)
        let alpha = MockEducationCampaign(id: "alpha", priority: 5)

        let registry = EducationCampaignRegistry(campaigns: [zeta, alpha])

        XCTAssertEqual(registry.campaigns.map(\.identity.id), ["zeta", "alpha"])
    }

    func testCampaignLookupById() {
        let first = MockEducationCampaign(id: "first", priority: 1)
        let second = MockEducationCampaign(id: "second", priority: 2)
        let registry = EducationCampaignRegistry(campaigns: [second, first])

        XCTAssertEqual(registry.campaign(id: "first")?.identity.id, "first")
        XCTAssertEqual(registry.campaign(id: "second")?.identity.id, "second")
        XCTAssertNil(registry.campaign(id: "missing"))
    }

    func testEmptyRegistry() {
        let registry = EducationCampaignRegistry(campaigns: [])
        XCTAssertTrue(registry.campaigns.isEmpty)
        XCTAssertNil(registry.campaign(id: "any"))
    }

    func testStateLookupByCampaignID() {
        let registry = EducationCampaignRegistry(campaigns: [])
        var completed = CampaignState.fresh(campaignID: "income_setup")
        completed.status = .completed
        let presented = CampaignState.fresh(campaignID: "custom_category")

        XCTAssertEqual(registry.state(for: "income_setup", in: [completed, presented]), completed)
        XCTAssertEqual(registry.state(for: "custom_category", in: [completed, presented]), presented)
        XCTAssertNil(registry.state(for: "missing", in: [completed, presented]))
    }
}
