//
//  RecurringTransactionManagerTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class RecurringTransactionManagerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testProcessPendingMarksSeriesInactiveWhenEndDateIsExhausted() async throws {
        let repository = InMemoryRecurringRepository()
        let manager = RecurringTransactionManager(repository: repository, calendar: calendar)
        let sink = RecordingTransactionSink()
        let start = date(2026, 8, 30)
        let end = date(2026, 9, 2)
        let now = date(2026, 9, 3)

        await manager.create(series(startDate: start, endDate: end, nextOccurrence: start))
        await manager.processPending(upTo: now, sink: sink, calendar: calendar)

        let stored = try await repository.fetchAll()
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].state, .inactive)
        XCTAssertNil(stored[0].nextOccurrence)
        XCTAssertEqual(sink.added.count, 4)
    }

    func testLoadHealsStaleActiveSeriesWithNoNextOccurrence() async throws {
        let repository = InMemoryRecurringRepository()
        let lastAdded = date(2026, 9, 2)
        let ended = series(
            startDate: date(2026, 8, 30),
            endDate: lastAdded,
            nextOccurrence: nil,
            lastTransactionAddedOn: lastAdded,
            state: .active
        )
        try await repository.upsert(ended)

        let manager = RecurringTransactionManager(repository: repository, calendar: calendar)
        let loaded = await manager.fetchAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].state, .inactive)
        XCTAssertNil(loaded[0].nextOccurrence)

        let stored = try await repository.fetchAll()
        XCTAssertEqual(stored[0].state, .inactive)
    }

    func testSkipPastEndDateMarksSeriesInactive() async throws {
        let repository = InMemoryRecurringRepository()
        let manager = RecurringTransactionManager(repository: repository, calendar: calendar)
        let today = date(2026, 9, 3)
        let item = series(startDate: today, endDate: today, nextOccurrence: today)

        await manager.create(item)
        await manager.skipNextOccurrence(id: item.id, calendar: calendar)

        let stored = try await repository.fetchAll()
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored[0].state, .inactive)
        XCTAssertNil(stored[0].nextOccurrence)
    }

    func testLoadDoesNotMarkPausedSeriesInactive() async throws {
        let repository = InMemoryRecurringRepository()
        let paused = series(
            startDate: date(2026, 8, 1),
            endDate: date(2026, 8, 15),
            nextOccurrence: nil,
            lastTransactionAddedOn: date(2026, 8, 15),
            state: .paused
        )
        try await repository.upsert(paused)

        let manager = RecurringTransactionManager(repository: repository, calendar: calendar)
        let loaded = await manager.fetchAll()

        XCTAssertEqual(loaded[0].state, .paused)
        XCTAssertNil(loaded[0].nextOccurrence)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func series(
        startDate: Date,
        endDate: Date?,
        nextOccurrence: Date?,
        lastTransactionAddedOn: Date? = nil,
        state: RecurringTransactionState = .active
    ) -> RecurringTransaction {
        RecurringTransaction(
            id: UUID(),
            title: "Rent",
            merchant: nil,
            type: TransactionType.expense.rawValue,
            categoryIdentifier: nil,
            amount: 100,
            startDate: startDate,
            endDate: endDate,
            recurrence: .daily,
            nextOccurrence: nextOccurrence,
            lastTransactionAddedOn: lastTransactionAddedOn,
            state: state,
            notificationReminderEnabled: false,
            notificationReminderOffsetFromEndOfDay: nil,
            notificationScheduledForOccurrenceDate: nil,
            metadata: nil
        )
    }
}

private final class InMemoryRecurringRepository: RecurringRepository, @unchecked Sendable {
    private var items: [UUID: RecurringTransaction] = [:]

    func fetchAll() async throws -> [RecurringTransaction] {
        Array(items.values)
    }

    func updatedAtById() async throws -> [UUID: Date] {
        [:]
    }

    func upsert(_ item: RecurringTransaction) async throws {
        items[item.id] = item
    }

    func delete(id: UUID) async throws {
        items[id] = nil
    }

    func clearAll() async throws {
        items.removeAll()
    }
}

private final class RecordingTransactionSink: TransactionSink {
    var added: [Transaction] = []

    func addTransaction(_ transaction: Transaction) async {
        added.append(transaction)
    }

    func hasMaterializedRecurringOccurrence(seriesId: String, occurrenceEpoch: TimeInterval) async -> Bool {
        added.contains {
            $0.recurringSeriesId == seriesId && $0.recurringOccurrenceDate == occurrenceEpoch
        }
    }
}
