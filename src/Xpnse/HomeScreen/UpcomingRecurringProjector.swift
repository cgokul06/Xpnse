//
//  UpcomingRecurringProjector.swift
//  Xpnse
//

import Foundation

struct UpcomingRecurringItem: Identifiable, Hashable {
    var id: String { "\(rule.id.uuidString)|\(occurrenceDate.timeIntervalSince1970)" }
    let rule: RecurringTransaction
    let occurrenceDate: Date

    var transactionType: TransactionType {
        TransactionType(rawValue: rule.type) ?? .expense
    }

    var categoryId: String {
        rule.categoryIdentifier ?? BuiltinCategories.defaultCategoryId(for: transactionType)
    }

    var amount: Double {
        Double(truncating: rule.amount as NSNumber)
    }
}

enum UpcomingRecurringProjector {
    static func materializationKey(seriesId: String, occurrenceEpoch: TimeInterval) -> String {
        "\(seriesId)|\(occurrenceEpoch)"
    }

    /// Projects non-materialized active recurring occurrences inside `period`.
    /// Occurrences before start-of-today are excluded (past months → empty).
    static func project(
        rules: [RecurringTransaction],
        periodStart: Date,
        periodEnd: Date,
        today: Date = Date(),
        calendar: Calendar = .current,
        materializedKeys: Set<String>
    ) -> [UpcomingRecurringItem] {
        let startOfToday = calendar.startOfDay(for: today)
        guard periodEnd >= startOfToday else { return [] }

        let rangeStart = max(periodStart, startOfToday)
        var results: [UpcomingRecurringItem] = []

        for rule in rules {
            guard rule.state == .active else { continue }

            var occurrence = rule.recurrence.firstOccurrence(
                onOrAfter: max(rangeStart, calendar.startOfDay(for: rule.startDate)),
                calendar: calendar
            )

            var safety = 0
            while let current = occurrence, safety < 128 {
                safety += 1
                if let endDate = rule.endDate, current > endDate { break }
                if current > periodEnd { break }

                if current >= rangeStart {
                    let key = materializationKey(
                        seriesId: rule.id.uuidString,
                        occurrenceEpoch: current.timeIntervalSince1970
                    )
                    if !materializedKeys.contains(key) {
                        results.append(UpcomingRecurringItem(rule: rule, occurrenceDate: current))
                    }
                }

                guard let next = rule.recurrence.nextOccurrence(after: current, calendar: calendar) else {
                    break
                }
                occurrence = next
            }
        }

        return results.sorted { $0.occurrenceDate > $1.occurrenceDate }
    }
}
