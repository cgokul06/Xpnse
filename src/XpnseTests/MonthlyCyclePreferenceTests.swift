//
//  MonthlyCyclePreferenceTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class MonthlyCyclePreferenceTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "monthly-cycle-preference-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        if let suiteName {
            defaults?.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testMissingKeyDefaultsToCalendarMonth() {
        XCTAssertEqual(MonthlyCyclePreference.load(from: defaults), .calendarMonth)
        XCTAssertEqual(MonthlyCyclePreference.load(from: defaults).startDay, 1)
    }

    func testZeroClampsToOne() {
        defaults.set(0, forKey: MonthlyCyclePreference.storageKey)
        XCTAssertEqual(MonthlyCyclePreference.load(from: defaults).startDay, 1)
    }

    func testThirtyOneClampsToThirty() {
        MonthlyCyclePreference.save(startDay: 31, to: defaults)
        XCTAssertEqual(MonthlyCyclePreference.load(from: defaults).startDay, 30)
        XCTAssertEqual(defaults.integer(forKey: MonthlyCyclePreference.storageKey), 30)
    }

    func testRoundTripStartDays() {
        for day in MonthlyCycleConfiguration.allowedStartDays {
            MonthlyCyclePreference.save(startDay: day, to: defaults)
            XCTAssertEqual(MonthlyCyclePreference.load(from: defaults).startDay, day)
        }
    }
}
