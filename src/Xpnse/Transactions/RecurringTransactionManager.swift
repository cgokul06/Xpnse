import Foundation

protocol TransactionSink {
    func addTransaction(_ transaction: Transaction) async
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
    /// On load, ensures `nextOccurrence` is set if missing.
    func load() async {
        do {
            let loaded = try await repository.fetchAll()
            items = loaded.map { item in
                var copy = item
                if copy.nextOccurrence == nil {
                    copy.nextOccurrence = copy.recurrence.firstOccurrence(onOrAfter: copy.startDate, calendar: calendar)
                }
                return copy
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
            guard var next = items[i].nextOccurrence else {
                continue
            }
            let endDate = items[i].endDate
            while next <= now, endDate.map({ next <= $0 }) ?? true {
                if let lastAdded = items[i].lastTransactionAddedOn,
                   calendar.isDate(lastAdded, inSameDayAs: next) {
                    guard let newNext = items[i].recurrence.nextOccurrence(after: next, calendar: calendar) else {
                        items[i].nextOccurrence = nil
                        changed = true
                        break
                    }
                    if let end = endDate, newNext > end {
                        items[i].nextOccurrence = nil
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
                        date: next.timeIntervalSince1970,
                        title: items[i].title,
                        recurringSeriesId: items[i].id.uuidString,
                        recurringOccurrenceDate: next.timeIntervalSince1970
                    )
                )
                items[i].lastTransactionAddedOn = next
                guard let newNext = items[i].recurrence.nextOccurrence(after: next, calendar: calendar) else {
                    items[i].nextOccurrence = nil
                    changed = true
                    break
                }
                if let end = endDate, newNext > end {
                    items[i].nextOccurrence = nil
                    changed = true
                    break
                }
                items[i].nextOccurrence = newNext
                next = newNext
                changed = true
            }
        }
        
        if changed {
            for item in items {
                try? await repository.upsert(item)
            }
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
        items[index].nextOccurrence = items[index].recurrence.nextOccurrence(after: next, calendar: calendar)
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
}
