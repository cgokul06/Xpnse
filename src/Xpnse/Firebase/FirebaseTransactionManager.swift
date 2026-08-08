//
//  FirebaseTransactionManager.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation
import Combine
import UserNotifications

struct CustomError {
    let code: Int
    let message: String
}

enum FirebaseErrorType: Error {
    case unauthorized
    case contextError
    case customError(CustomError)
    case noDocumentFound
}

final class FirebaseTransactionManager {
    static let shared = FirebaseTransactionManager()

    private let transactionRepository: TransactionRepository
    private let recurringTransactionManager: RecurringTransactionManager

    private init(
        transactionRepository: TransactionRepository = SwiftDataTransactionRepository.shared,
        recurringTransactionManager: RecurringTransactionManager = RecurringTransactionManager()
    ) {
        self.transactionRepository = transactionRepository
        self.recurringTransactionManager = recurringTransactionManager
    }

    private var recurringProcessTask: Task<Void, Never>?

    func processRecurringTransactions() {
        Task { await processRecurringTransactionsAsync() }
    }

    @MainActor
    func processRecurringTransactionsAsync() async {
        if let recurringProcessTask {
            await recurringProcessTask.value
            return
        }

        let task = Task { @MainActor in
            await self.recurringTransactionManager.loadAndProcess(sink: self)
            await self.linkUntaggedTransactionsToRecurringSeries()
            await RecurringReminderScheduler.shared.reconcileAllPendingReminders()
        }
        recurringProcessTask = task
        await task.value
        recurringProcessTask = nil
    }

    /// Attach `recurringSeriesId` to existing txs that match a rule but were never tagged
    /// (legacy seeds, imports, or rules created after a one-off). Enables the Recurring badge.
    /// Only tags transactions on/after the rule start date (and on/before end date when set).
    private func linkUntaggedTransactionsToRecurringSeries() async {
        do {
            let rules = await recurringTransactionManager.fetchAll()
                .filter { $0.state == .active || $0.state == .paused }
            guard !rules.isEmpty else { return }

            let all = try await transactionRepository.fetchAll()
            let calendar = Calendar.current
            let rulesById = Dictionary(uniqueKeysWithValues: rules.map { ($0.id.uuidString, $0) })

            // Clear series tags when a tx falls outside the rule window (e.g. start date moved).
            for transaction in all {
                guard let seriesId = transaction.recurringSeriesId,
                      let rule = rulesById[seriesId],
                      !RecurringTransactionMatcher.isWithinRuleDateWindow(
                        transaction,
                        rule: rule,
                        calendar: calendar
                      )
                else { continue }
                var updated = transaction
                updated.recurringSeriesId = nil
                updated.recurringOccurrenceDate = nil
                try await transactionRepository.update(updated)
            }

            let untagged = try await transactionRepository.fetchAll()
            for transaction in untagged where transaction.recurringSeriesId == nil {
                guard let rule = rules.first(where: {
                    RecurringTransactionMatcher.matches(transaction, rule: $0, calendar: calendar)
                }) else { continue }

                var updated = transaction
                updated.recurringSeriesId = rule.id.uuidString
                if updated.recurringOccurrenceDate == nil {
                    updated.recurringOccurrenceDate = transaction.date
                }
                try await transactionRepository.update(updated)
            }
        } catch {
            DeviceDebugLogger.log(
                "recurring series backfill failed",
                category: "recurring.link",
                data: ["error": error.localizedDescription]
            )
        }
    }

    private var listeners: Set<String> = []
    var changesPublisher: AnyPublisher<Void, Never> {
        transactionRepository.changesPublisher
    }

    static func setup(authManager: FirebaseAuthManager) {
        // Kept for call-site compatibility while removing login dependencies.
        _ = authManager
    }

    static func reset() {
        // No-op for local SwiftData-backed storage.
    }


    // MARK: - CRUD Operations

    func addTransaction(_ transaction: Transaction) async {
        do {
            try await transactionRepository.add(transaction)
            await MainActor.run {
                UserSatisfactionEngine.shared.track(.transactionAdded)
            }
        } catch {
            print("Failed to add transaction: \(error.localizedDescription)")
            await MainActor.run {
                UserSatisfactionEngine.shared.track(.criticalErrorOccurred)
            }
        }
    }

    func updateTransaction(_ transaction: Transaction) async {
        do {
            try await transactionRepository.update(transaction)
        } catch {
            print("Failed to update transaction: \(error.localizedDescription)")
            await MainActor.run {
                UserSatisfactionEngine.shared.track(.criticalErrorOccurred)
            }
        }
    }

        func deleteTransaction(_ transaction: Transaction) async {
            do {
                try await transactionRepository.delete(transaction)
            } catch {
                print("Failed to delete transaction: \(error.localizedDescription)")
                await MainActor.run {
                    UserSatisfactionEngine.shared.track(.criticalErrorOccurred)
                }
            }
        }

    func loadTransactions(
        startDate: Date,
        endDate: Date,
        range: CalendarComparison,
        onUpdate: @escaping (Result<TransactionSummary, FirebaseErrorType>) -> Void
    ) async throws {
        let key = "\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)"
        removeListener(for: key)
        listeners.insert(key)
        let transactions = try await transactionRepository.fetch(startDate: startDate, endDate: endDate)
        var parsedTransactions: [Date: [Transaction]] = [:]

        for transaction in transactions {
            let date = Date(timeIntervalSince1970: transaction.date)
            let dateOfTransaction = Calendar.current.startOfDay(for: date)
            parsedTransactions[dateOfTransaction, default: []].append(transaction)
        }

        let summary = TransactionSummary(
            transactions: parsedTransactions,
            startDate: startDate,
            endDate: endDate,
            range: range
        )
        onUpdate(.success(summary))
    }

    // MARK: - Remove Specific Listener
    func removeListener(for key: String) {
        listeners.remove(key)
    }

    // MARK: - Remove All Listeners
    func removeAllListeners() {
        listeners = []
    }

    func clearAll() async {
        do {
            try await transactionRepository.clearAll()
            try await SwiftDataRecurringRepository.shared.clearAll()
            try await SwiftDataCategoryRepository.shared.clearAll()
            try await PotentialRecurringDismissStore.clearAll()
            await CategoryStore.shared.load()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        } catch {
            print("Failed to clear local data: \(error.localizedDescription)")
        }
    }

    func createRecurringTransaction(_ recurring: RecurringTransaction) async {
        await recurringTransactionManager.create(recurring)
        await RecurringReminderScheduler.shared.handleRecurringSaved(recurring)
    }

    /// Tag an existing one-off as belonging to a recurring series (Insights convert flow).
    func linkTransaction(
        id: String,
        toRecurringSeriesId seriesId: String,
        occurrenceDate: Double
    ) async {
        do {
            let all = try await transactionRepository.fetchAll()
            guard var transaction = all.first(where: { $0.id == id }) else { return }
            transaction.recurringSeriesId = seriesId
            transaction.recurringOccurrenceDate = occurrenceDate
            try await transactionRepository.update(transaction)
        } catch {
            DeviceDebugLogger.log(
                "link transaction to recurring failed",
                category: "recurring.link",
                data: ["error": error.localizedDescription]
            )
        }
    }

    func updateRecurringTransaction(_ recurring: RecurringTransaction) async {
        await recurringTransactionManager.update(recurring)
        await backfillGeneratedTransactions(from: recurring)
        await RecurringReminderScheduler.shared.handleRecurringSaved(recurring)
    }

    /// Propagate rule title/merchant onto already-materialized occurrences so Insights
    /// (and lists) do not split one series across "description" and "merchant" payees.
    private func backfillGeneratedTransactions(from recurring: RecurringTransaction) async {
        let seriesId = recurring.id.uuidString
        do {
            let all = try await transactionRepository.fetchAll()
            for transaction in all where transaction.recurringSeriesId == seriesId {
                var updated = transaction
                var changed = false
                if updated.title != recurring.title {
                    updated.title = recurring.title
                    changed = true
                }
                if updated.merchant != recurring.merchant {
                    updated.merchant = recurring.merchant
                    changed = true
                }
                if changed {
                    try await transactionRepository.update(updated)
                }
            }
        } catch {
            print("Failed to backfill recurring series transactions: \(error.localizedDescription)")
        }
    }

    func cancelRecurringTransaction(id: UUID) async {
        await recurringTransactionManager.cancel(id: id)
        await RecurringReminderScheduler.shared.cancelReminder(for: id)
    }

    func skipRecurringTransaction(id: UUID) async {
        await recurringTransactionManager.skipNextOccurrence(id: id)
        let all = await recurringTransactionManager.fetchAll()
        if let updated = all.first(where: { $0.id == id }) {
            await RecurringReminderScheduler.shared.handleRecurringSaved(updated)
        }
    }

    func deleteRecurringTransaction(id: UUID) async {
        await recurringTransactionManager.markDeleted(id: id)
        await RecurringReminderScheduler.shared.cancelReminder(for: id)
    }

    func fetchRecurringTransactions() async -> [RecurringTransaction] {
        await recurringTransactionManager.fetchAll()
    }
}

extension FirebaseTransactionManager: TransactionSink {
    func hasMaterializedRecurringOccurrence(seriesId: String, occurrenceEpoch: TimeInterval) async -> Bool {
        (try? await transactionRepository.hasRecurringOccurrence(
            seriesId: seriesId,
            occurrenceEpoch: occurrenceEpoch
        )) ?? false
    }

    func materializedRecurringOccurrenceKeys(
        startDate: Date,
        endDate: Date
    ) async -> Set<String> {
        (try? await transactionRepository.materializedRecurringOccurrenceKeys(
            startEpoch: startDate.timeIntervalSince1970,
            endEpoch: endDate.timeIntervalSince1970
        )) ?? []
    }
}
