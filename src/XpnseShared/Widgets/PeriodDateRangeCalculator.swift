//
//  PeriodDateRangeCalculator.swift
//  Xpnse
//

import Foundation

enum PeriodDateRangeCalculator {
    static func dateRange(
        forOffset offset: Int,
        comparison: CalendarComparison,
        calendar: Calendar = .current,
        referenceDate: Date = Date(),
        configuration: MonthlyCycleConfiguration = MonthlyCyclePreference.current
    ) -> (start: Date, end: Date) {
        switch comparison {
        case .monthly:
            let resolver = MonthlyCycleResolver(configuration: configuration, calendar: calendar)
            let cycle = resolver.cycle(offset: offset, from: referenceDate)
            return (cycle.start, cycle.inclusiveFetchEnd)

        case .yearly:
            guard let yearDate = calendar.date(byAdding: .year, value: offset, to: referenceDate),
                  let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: yearDate)),
                  let startOfNextYear = calendar.date(byAdding: .year, value: 1, to: startOfYear),
                  let endOfYear = calendar.date(byAdding: .second, value: -1, to: startOfNextYear)
            else {
                return (referenceDate, referenceDate)
            }
            return (startOfYear, endOfYear)
        }
    }
}
