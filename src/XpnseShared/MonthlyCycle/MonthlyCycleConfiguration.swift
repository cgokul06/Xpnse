//
//  MonthlyCycleConfiguration.swift
//  XpnseShared
//

import Foundation

/// How a monthly billing cycle is determined. Phase 1 supports a fixed start day;
/// additional kinds can be added without changing cycle consumers.
enum MonthlyCycleKind: String, Sendable, Equatable {
    case fixedStartDay
}

/// User-facing monthly cycle configuration. Consumers should depend on
/// `MonthlyCycleResolver` rather than reading `startDay` directly.
struct MonthlyCycleConfiguration: Equatable, Sendable {
    static let allowedStartDays = 1...30

    var kind: MonthlyCycleKind
    /// 1...30. Ignored by kinds other than `fixedStartDay`.
    var startDay: Int

    static let calendarMonth = MonthlyCycleConfiguration(kind: .fixedStartDay, startDay: 1)

    static func fixedStartDay(_ day: Int) -> MonthlyCycleConfiguration {
        MonthlyCycleConfiguration(kind: .fixedStartDay, startDay: clampedStartDay(day))
    }

    static func clampedStartDay(_ day: Int) -> Int {
        min(max(day, allowedStartDays.lowerBound), allowedStartDays.upperBound)
    }

    var clamped: MonthlyCycleConfiguration {
        MonthlyCycleConfiguration(kind: kind, startDay: Self.clampedStartDay(startDay))
    }
}
