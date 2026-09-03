//
//  MonthlyCycleResolver.swift
//  XpnseShared
//

import Foundation

/// Single source of truth for monthly billing-cycle boundaries.
struct MonthlyCycleResolver: Sendable {
    let configuration: MonthlyCycleConfiguration
    let calendar: Calendar

    init(
        configuration: MonthlyCycleConfiguration = .calendarMonth,
        calendar: Calendar = .current
    ) {
        self.configuration = configuration.clamped
        self.calendar = calendar
    }

    func currentCycle(for date: Date = Date()) -> BillingCycle {
        cycleContaining(date)
    }

    func cycleContaining(_ date: Date) -> BillingCycle {
        switch configuration.kind {
        case .fixedStartDay:
            return fixedStartDayCycleContaining(date)
        }
    }

    func nextCycle(from cycle: BillingCycle) -> BillingCycle {
        makeCycle(start: cycle.nextStart)
    }

    func previousCycle(from cycle: BillingCycle) -> BillingCycle {
        let shifted = shiftCycleStart(cycle.start, byMonths: -1)
        return makeCycle(start: shifted)
    }

    /// Offset `0` is the cycle containing `referenceDate`; `±N` is N cycles away.
    func cycle(offset: Int, from referenceDate: Date = Date()) -> BillingCycle {
        let current = currentCycle(for: referenceDate)
        if offset == 0 { return current }
        let shiftedStart = shiftCycleStart(current.start, byMonths: offset)
        return makeCycle(start: shiftedStart)
    }

    /// Cycle whose start falls in the given calendar month.
    func cycleStarting(year: Int, month: Int) -> BillingCycle? {
        guard let start = cycleStart(year: year, month: month) else { return nil }
        return makeCycle(start: start)
    }

    func priorCycleKeys(from focus: BillingCycle, count: Int) -> [(Int, Int)] {
        guard count > 0 else { return [] }
        var cycle = focus
        var keys: [(Int, Int)] = []
        keys.reserveCapacity(count)
        for _ in 0..<count {
            cycle = previousCycle(from: cycle)
            keys.append((cycle.startYear, cycle.startMonth))
        }
        return keys.reversed()
    }

    // MARK: - Fixed start day

    private func fixedStartDayCycleContaining(_ date: Date) -> BillingCycle {
        let day = calendar.startOfDay(for: date)
        let comps = calendar.dateComponents([.year, .month], from: day)
        guard let year = comps.year,
              let month = comps.month,
              let thisMonthStart = cycleStart(year: year, month: month)
        else {
            return fallbackCycle(for: date)
        }

        if day >= thisMonthStart {
            return makeCycle(start: thisMonthStart)
        }

        let previousStart = shiftCycleStart(thisMonthStart, byMonths: -1)
        return makeCycle(start: previousStart)
    }

    /// Apply configured start day `D` to calendar month `(year, month)`, clamping to the last day.
    private func cycleStart(year: Int, month: Int) -> Date? {
        guard let monthAnchor = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let dayRange = calendar.range(of: .day, in: .month, for: monthAnchor)
        else { return nil }
        let day = min(configuration.startDay, dayRange.count)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else { return nil }
        return calendar.startOfDay(for: date)
    }

    /// Shift by calendar months from the cycle-start's year/month, then re-apply `D`.
    /// Never adds months to a clamped February date (that would yield 28 Mar instead of 30 Mar).
    private func shiftCycleStart(_ start: Date, byMonths months: Int) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: start)
        guard let year = comps.year,
              let month = comps.month,
              let anchor = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let shifted = calendar.date(byAdding: .month, value: months, to: anchor)
        else { return start }
        let shiftedComps = calendar.dateComponents([.year, .month], from: shifted)
        guard let shiftedYear = shiftedComps.year,
              let shiftedMonth = shiftedComps.month,
              let nextStart = cycleStart(year: shiftedYear, month: shiftedMonth)
        else { return start }
        return nextStart
    }

    private func makeCycle(start: Date) -> BillingCycle {
        let normalizedStart = calendar.startOfDay(for: start)
        let nextStart = shiftCycleStart(normalizedStart, byMonths: 1)
        return BillingCycle(start: normalizedStart, nextStart: nextStart, calendar: calendar)
    }

    private func fallbackCycle(for date: Date) -> BillingCycle {
        let start = calendar.startOfDay(for: date)
        let nextStart = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return BillingCycle(start: start, nextStart: nextStart, calendar: calendar)
    }
}
