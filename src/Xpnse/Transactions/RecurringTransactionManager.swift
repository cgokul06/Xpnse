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
            guard var next = items[i].nextOccurrence else {
                continue
            }
            let endDate = items[i].endDate
            while next <= now, endDate.map({ next <= $0 }) ?? true {
                await sink.addTransaction(
                    Transaction(
                        id: UUID().uuidString,
                        type: TransactionType(rawValue: items[i].type) ?? .expense,
                        category: TransactionCategory(rawValue: items[i].categoryIdentifier!) ?? .other,
                        amount: Double(truncating: items[i].amount as NSNumber),
                        title: items[i].title
                    )
                )
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
}
