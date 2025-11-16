import Foundation
import FirebaseFirestore

/// Protocol for a sink that accepts created transactions.
public protocol TransactionSink: Sendable {
    /// Adds a transaction with given details.
    /// - Parameters:
    ///   - title: Title or description.
    ///   - categoryIdentifier: Optional category identifier.
    ///   - amount: Transaction amount.
    ///   - date: Date of the transaction.
    func addTransaction(title: String, categoryIdentifier: String?, amount: Decimal, date: Date)
}

/// Manager for recurring transactions: persists and processes them using a repository backing (e.g. Firestore).
public final class RecurringTransactionManager {
    private var items: [RecurringTransaction] = []
    private let repository: RecurringRepository
    private let calendar: Calendar
    private let authManager: FirebaseAuthManager

    /// Initializes the manager, setting up repository and calendar.
    /// - Parameters:
    ///   - repository: Repository instance for persistence.
    ///   - userIdProvider: Closure to get current user id.
    ///   - calendar: Calendar to use for date calculations. Defaults to current.
    init(
        repository: RecurringRepository = FirestoreRecurringRepository.shared,
        authManager: FirebaseAuthManager,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.authManager = authManager
        self.calendar = calendar
    }

    /// Creates and stores a new recurring transaction asynchronously.
    /// - Parameter item: The recurring transaction to create.
    public func create(_ item: RecurringTransaction) async {
        guard let userId = authManager.userId else {
            return
        }

        items.append(item)
        try? await repository.upsert(item, for: userId)
    }

    /// Updates an existing recurring transaction asynchronously by matching id.
    /// - Parameter item: The updated recurring transaction.
    public func update(_ item: RecurringTransaction) async {
        guard let userId = authManager.userId else {
            return
        }

        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        items[index] = item
        try? await repository.upsert(item, for: userId)
    }

    /// Deletes a recurring transaction asynchronously by its identifier.
    /// - Parameter id: The UUID of the transaction to delete.
    public func delete(id: UUID) async {
        guard let userId = authManager.userId else {
            return
        }

        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items.remove(at: index)
        try? await repository.delete(id: id, for: userId)
    }

    /// Returns all stored recurring transactions.
    /// - Returns: Array of recurring transactions.
    public func all() -> [RecurringTransaction] {
        return items
    }

    /// Loads recurring transactions asynchronously from the repository.
    /// On load, ensures `nextOccurrence` is set if missing.
    public func load() async {
        guard let userId = authManager.userId else {
            return
        }

        do {
            let loaded = try await repository.fetchAll(for: userId)
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
    public func processPending(
        upTo now: Date = Date(),
        sink: TransactionSink,
        calendar: Calendar = .current
    ) async {
        guard let userId = authManager.userId else {
            return
        }

        var changed = false
        for i in items.indices {
            guard var next = items[i].nextOccurrence else {
                continue
            }
            let endDate = items[i].endDate
            while next <= now, endDate.map({ next <= $0 }) ?? true {
                sink.addTransaction(
                    title: items[i].title,
                    categoryIdentifier: items[i].categoryIdentifier,
                    amount: items[i].amount,
                    date: next
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
                try? await repository.upsert(item, for: userId)
            }
        }
    }
}
