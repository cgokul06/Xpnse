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
        let sink = RecordingTransactionSink(calendar: calendar)
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

    func testProcessPendingUsesStartOfDayInsteadOfAddedTime() async throws {
        let repository = InMemoryRecurringRepository()
        let manager = RecurringTransactionManager(repository: repository, calendar: calendar)
        let sink = RecordingTransactionSink(calendar: calendar)
        let today = date(2026, 9, 3)
        let addedTime = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: today)!
        let morning = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today)!

        await manager.create(
            series(startDate: addedTime, endDate: nil, nextOccurrence: addedTime)
        )
        await manager.processPending(upTo: morning, sink: sink, calendar: calendar)

        XCTAssertEqual(sink.added.count, 1)
        let materialized = Date(timeIntervalSince1970: sink.added[0].date)
        XCTAssertEqual(calendar.startOfDay(for: materialized), today)
        XCTAssertEqual(calendar.component(.hour, from: materialized), 0)

        let stored = try await repository.fetchAll()
        XCTAssertEqual(stored[0].nextOccurrence, calendar.date(byAdding: .day, value: 1, to: today))
    }

    func testProcessPendingDoesNotDuplicateAfternoonOccurrence() async throws {
        let repository = InMemoryRecurringRepository()
        let manager = RecurringTransactionManager(repository: repository, calendar: calendar)
        let today = date(2026, 9, 3)
        let addedTime = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: today)!
        let item = series(startDate: addedTime, endDate: nil, nextOccurrence: today)
        let sink = RecordingTransactionSink(calendar: calendar)
        sink.added = [
            Transaction(
                id: UUID().uuidString,
                type: .expense,
                categoryId: BuiltinCategories.otherCategoryId,
                amount: 100,
                date: addedTime.timeIntervalSince1970,
                title: "Rent",
                recurringSeriesId: item.id.uuidString,
                recurringOccurrenceDate: addedTime.timeIntervalSince1970
            )
        ]

        await manager.create(item)
        await manager.processPending(upTo: today, sink: sink, calendar: calendar)

        XCTAssertEqual(sink.added.count, 1)
    }

    func testConvertLinkedStartDayIsNotRematerialized() async throws {
        let repository = InMemoryRecurringRepository()
        let manager = RecurringTransactionManager(repository: repository, calendar: calendar)
        let sink = RecordingTransactionSink(calendar: calendar)
        let today = date(2026, 9, 3)
        let addedTime = calendar.date(bySettingHour: 15, minute: 30, second: 0, of: today)!

        await manager.create(
            series(
                startDate: addedTime,
                endDate: nil,
                nextOccurrence: addedTime,
                lastTransactionAddedOn: addedTime
            )
        )
        await manager.processPending(upTo: today, sink: sink, calendar: calendar)

        XCTAssertTrue(sink.added.isEmpty)
        let stored = try await repository.fetchAll()
        XCTAssertEqual(stored[0].nextOccurrence, calendar.date(byAdding: .day, value: 1, to: today))
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
    private let calendar: Calendar
    var added: [Transaction] = []

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func addTransaction(_ transaction: Transaction) async {
        added.append(transaction)
    }

    func hasMaterializedRecurringOccurrence(seriesId: String, occurrenceEpoch: TimeInterval) async -> Bool {
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: occurrenceEpoch))
        return added.contains {
            guard $0.recurringSeriesId == seriesId,
                  let stored = $0.recurringOccurrenceDate else { return false }
            return calendar.startOfDay(for: Date(timeIntervalSince1970: stored)) == day
        }
    }
}
