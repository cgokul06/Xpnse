//
//  BillingCycle.swift
//  XpnseShared
//

import Foundation

/// One billing period as a half-open interval `[start, nextStart)`.
/// `start` and `nextStart` are start-of-local-day instants.
struct BillingCycle: Equatable, Sendable {
    let start: Date
    let nextStart: Date
    let calendar: Calendar

    /// Inclusive last calendar day of the cycle (`nextStart` minus 1 day).
    var endDate: Date {
        calendar.date(byAdding: .day, value: -1, to: nextStart) ?? start
    }

    /// Inclusive end instant for existing `fetch(startDate:endDate:)` predicates.
    var inclusiveFetchEnd: Date {
        nextStart.addingTimeInterval(-1)
    }

    var startYear: Int {
        calendar.component(.year, from: start)
    }

    var startMonth: Int {
        calendar.component(.month, from: start)
    }

    /// Identity used by Insights summaries (`year-month` of the cycle start).
    var identityKey: String {
        "\(startYear)-\(startMonth)"
    }

    /// Number of calendar days in the cycle (`nextStart - start`).
    var lengthInDays: Int {
        calendar.dateComponents([.day], from: start, to: nextStart).day ?? 0
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date < nextStart
    }

    /// 1-based day index within the cycle (cycle start = 1). Nil if `date` is outside.
    func dayIndex(of date: Date) -> Int? {
        let dayStart = calendar.startOfDay(for: date)
        guard dayStart >= start && dayStart < nextStart else { return nil }
        let days = calendar.dateComponents([.day], from: start, to: dayStart).day ?? 0
        return days + 1
    }

    func dateForDayIndex(_ index: Int) -> Date? {
        guard index >= 1, index <= lengthInDays else { return nil }
        return calendar.date(byAdding: .day, value: index - 1, to: start)
    }
}
