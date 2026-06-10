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
        referenceDate: Date = Date()
    ) -> (start: Date, end: Date) {
        switch comparison {
        case .monthly:
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: referenceDate),
                  let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)),
                  let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth),
                  let endOfMonth = calendar.date(byAdding: .second, value: -1, to: startOfNextMonth)
            else {
                return (referenceDate, referenceDate)
            }
            return (startOfMonth, endOfMonth)

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
