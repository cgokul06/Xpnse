import Foundation

protocol TransactionSink {
    func addTransaction(_ transaction: Transaction) async
    func hasMaterializedRecurringOccurrence(seriesId: String, occurrenceEpoch: TimeInterval) async -> Bool
}

/// Manager for recurring transactions: persists and processes them using a repository backing (e.g. Firestore).
final class RecurringTransactionManager {
    private var items: [RecurringTransaction] = []
    private let repository: RecurringRepository
    private let calendar: Calendar

    /// Initializes the manager, setting up repository and calendar.
    /// - Parameters:
    ///   - repository: Repository instance for persistence.
    ///   - userIdProvider: Closure to get current user id.
    ///   - calendar: Calendar to use for date calculations. Defaults to current.
    init(
        repository: RecurringRepository = SwiftDataRecurringRepository.shared,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.calendar = calendar
    }

    /// Creates and stores a new recurring transaction asynchronously.
    /// - Parameter item: The recurring transaction to create.
    func create(_ item: RecurringTransaction) async {
        items.append(item)
        try? await repository.upsert(item)
    }

    /// Updates an existing recurring transaction asynchronously by matching id.
    /// - Parameter item: The updated recurring transaction.
    func update(_ item: RecurringTransaction) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        items[index] = item
        try? await repository.upsert(item)
    }

    /// Deletes a recurring transaction asynchronously by its identifier.
    /// - Parameter id: The UUID of the transaction to delete.
    func delete(id: UUID) async {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items.remove(at: index)
        try? await repository.delete(id: id)
    }

    /// Returns all stored recurring transactions.
    /// - Returns: Array of recurring transactions.
    func all() -> [RecurringTransaction] {
        return items
    }

    func fetchAll() async -> [RecurringTransaction] {
        await self.load()
        return items
    }

    func loadAndProcess(sink: TransactionSink) async {
        await self.load()
        await self.processPending(sink: sink)
    }

    /// Loads recurring transactions asynchronously from the repository.
    /// Active series with no remaining occurrence are persisted as `.inactive`.
    /// Missing `nextOccurrence` is restored only when the series is still active.
    func load() async {
        do {
            items = try await repository.fetchAll()
            var changed = false
            for i in items.indices {
                guard items[i].state == .active else { continue }
                if let remaining = remainingOccurrence(for: items[i], calendar: calendar) {
                    if items[i].nextOccurrence != remaining {
                        items[i].nextOccurrence = remaining
                        changed = true
                    }
                } else {
                    markInactive(at: i)
                    changed = true
                }
            }
            if changed {
                await persistAll()
            }
        } catch {
            items = []
        }
    }

    /// Processes all pending occurrences up to the given date asynchronously.
    /// For each occurrence due, calls `sink.addTransaction(...)` and advances the `nextOccurrence`.
    /// Saves changes if any `nextOccurrence` values were updated via the repository.
    /// - Parameters:
    ///   - now: The date up to which to process occurrences. Defaults to current date.
    ///   - sink: The sink to receive created transactions.
    ///   - calendar: Calendar to use for date calculations. Defaults to current.
    func processPending(
        upTo now: Date = Date(),
        sink: TransactionSink,
        calendar: Calendar = .current
    ) async {
        var changed = false
        for i in items.indices {
            guard items[i].state == .active else {
                continue
            }
            guard var next = remainingOccurrence(for: items[i], calendar: calendar) else {
                markInactive(at: i)
                changed = true
                continue
            }
            if items[i].nextOccurrence != next {
                items[i].nextOccurrence = next
                changed = true
            }
            let nowDay = calendar.startOfDay(for: now)
            var safety = 0
            while calendar.startOfDay(for: next) <= nowDay,
                  isWithinEndDate(next, endDate: items[i].endDate, calendar: calendar),
                  safety < 128 {
                safety += 1
                // Never re-materialize on or before the last added day. Editing a rule
                // can reset `nextOccurrence` earlier in the series; only advance past those days.
                if let lastAdded = items[i].lastTransactionAddedOn {
                    let nextDay = calendar.startOfDay(for: next)
                    let lastDay = calendar.startOfDay(for: lastAdded)
                    if nextDay <= lastDay {
                        guard let newNext = advanceOrMarkInactive(at: i, after: next, calendar: calendar) else {
                            changed = true
                            break
                        }
                        items[i].nextOccurrence = newNext
                        next = newNext
                        changed = true
                        continue
                    }
                }

                let occurrenceDay = calendar.startOfDay(for: next)
                let alreadyExists = await sink.hasMaterializedRecurringOccurrence(
                    seriesId: items[i].id.uuidString,
                    occurrenceEpoch: occurrenceDay.timeIntervalSince1970
                )
                if alreadyExists {
                    items[i].lastTransactionAddedOn = occurrenceDay
                    guard let newNext = advanceOrMarkInactive(at: i, after: occurrenceDay, calendar: calendar) else {
                        changed = true
                        break
                    }
                    items[i].nextOccurrence = newNext
                    next = newNext
                    changed = true
                    continue
                }

                await sink.addTransaction(
                    Transaction(
                        id: UUID().uuidString,
                        type: TransactionType(rawValue: items[i].type) ?? .expense,
                        categoryId: items[i].categoryIdentifier ?? BuiltinCategories.otherCategoryId,
                        amount: Double(truncating: items[i].amount as NSNumber),
                        date: occurrenceDay.timeIntervalSince1970,
                        title: items[i].title,
                        merchant: items[i].merchant,
                        recurringSeriesId: items[i].id.uuidString,
                        recurringOccurrenceDate: occurrenceDay.timeIntervalSince1970
                    )
                )
                items[i].lastTransactionAddedOn = occurrenceDay
                guard let newNext = advanceOrMarkInactive(at: i, after: occurrenceDay, calendar: calendar) else {
                    changed = true
                    break
                }
                items[i].nextOccurrence = newNext
                next = newNext
                changed = true
            }

            if items[i].state == .active, remainingOccurrence(for: items[i], calendar: calendar) == nil {
                markInactive(at: i)
                changed = true
            }
        }

        if changed {
            await persistAll()
        }
    }

    func cancel(id: UUID, at date: Date = Date()) async {
        _ = date
        await self.load()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = .paused
        items[index].nextOccurrence = nil
        items[index].notificationScheduledForOccurrenceDate = nil
        try? await repository.upsert(items[index])
    }

    func skipNextOccurrence(id: UUID, calendar: Calendar = .current) async {
        await self.load()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        guard items[index].state == .active else { return }
        guard let next = items[index].nextOccurrence else { return }
        if let newNext = advanceOrMarkInactive(at: index, after: next, calendar: calendar) {
            items[index].nextOccurrence = newNext
        }
        try? await repository.upsert(items[index])
    }

    func markDeleted(id: UUID) async {
        await self.load()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].state = .deleted
        items[index].nextOccurrence = nil
        items[index].notificationReminderEnabled = false
        items[index].notificationReminderOffsetFromEndOfDay = nil
        items[index].notificationScheduledForOccurrenceDate = nil
        try? await repository.upsert(items[index])
    }

    private func remainingOccurrence(for item: RecurringTransaction, calendar: Calendar) -> Date? {
        let candidate: Date?
        if let next = item.nextOccurrence {
            candidate = next
        } else if let lastAdded = item.lastTransactionAddedOn {
            candidate = item.recurrence.nextOccurrence(after: lastAdded, calendar: calendar)
        } else {
            candidate = item.recurrence.firstOccurrence(onOrAfter: item.startDate, calendar: calendar)
        }
        guard let next = candidate, isWithinEndDate(next, endDate: item.endDate, calendar: calendar) else {
            return nil
        }
        return calendar.startOfDay(for: next)
    }

    private func advanceOrMarkInactive(at index: Int, after current: Date, calendar: Calendar) -> Date? {
        guard let newNext = items[index].recurrence.nextOccurrence(after: current, calendar: calendar),
              isWithinEndDate(newNext, endDate: items[index].endDate, calendar: calendar)
        else {
            markInactive(at: index)
            return nil
        }
        return calendar.startOfDay(for: newNext)
    }

    private func isWithinEndDate(_ date: Date, endDate: Date?, calendar: Calendar) -> Bool {
        guard let endDate else { return true }
        return calendar.startOfDay(for: date) <= calendar.startOfDay(for: endDate)
    }

    private func markInactive(at index: Int) {
        items[index].state = .inactive
        items[index].nextOccurrence = nil
        items[index].notificationScheduledForOccurrenceDate = nil
    }

    private func persistAll() async {
        for item in items {
            try? await repository.upsert(item)
        }
    }
}
