//
//  ExportImportService.swift
//  Xpnse
//
//  Created by Gokul C on 04/05/26.
//

import Foundation

enum ExportImportError: Error {
    case invalidBackup
    case unsupportedSchemaVersion(Int)
}

struct ExportImportService {
    /// 5: recurring reminders store `notificationReminderOffsetFromEndOfDay` (seconds before end of occurrence day).
    private static let currentSchemaVersion = 5

    private let transactionRepository: TransactionRepository
    private let recurringRepository: RecurringRepository

    init(
        transactionRepository: TransactionRepository = SwiftDataTransactionRepository.shared,
        recurringRepository: RecurringRepository = SwiftDataRecurringRepository.shared
    ) {
        self.transactionRepository = transactionRepository
        self.recurringRepository = recurringRepository
    }

    func exportAllData() async throws -> String {
        let transactions = try await transactionRepository.fetchAll()
        let recurringTransactions = try await recurringRepository.fetchAll()
        let recurringUpdatedAt = try await recurringRepository.updatedAtById()
        let recurringUpdatedAtById = Dictionary(
            uniqueKeysWithValues: recurringUpdatedAt.map { ($0.key.uuidString, $0.value) }
        )

        let payload = BackupPayload(
            schemaVersion: Self.currentSchemaVersion,
            exportedAt: Date(),
            settings: BackupSettings(
                selectedCurrencyCode: CurrencyManager.shared.selectedCurrency.code
            ),
            transactionUpdatedAtById: try await transactionRepository.updatedAtById(),
            recurringUpdatedAtById: recurringUpdatedAtById,
            transactions: transactions,
            recurringTransactions: recurringTransactions
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    func importAllData(_ text: String) async throws {
        guard let data = text.data(using: .utf8) else {
            throw ExportImportError.invalidBackup
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload: BackupPayload
        do {
            payload = try decoder.decode(BackupPayload.self, from: data)
        } catch {
            throw ExportImportError.invalidBackup
        }

        guard payload.schemaVersion <= Self.currentSchemaVersion else {
            throw ExportImportError.unsupportedSchemaVersion(payload.schemaVersion)
        }

        try await mergeTransactionsOneByOne(payload.transactions, payload: payload)
        try await mergeRecurringOneByOne(payload.recurringTransactions, payload: payload)

        if let selectedCurrencyCode = payload.settings?.selectedCurrencyCode,
           let selectedCurrency = CurrencyManager.shared.currency(for: selectedCurrencyCode) {
            CurrencyManager.shared.selectedCurrency = selectedCurrency
        }

        scheduleSuggestionRebuildAfterImport()
        await RecurringReminderScheduler.shared.reconcileAllPendingReminders()
    }

    private func mergeTransactionsOneByOne(_ imported: [Transaction], payload: BackupPayload) async throws {
        var existing = try await transactionRepository.fetchAll()
        let existingUpdatedAtById = try await transactionRepository.updatedAtById()
        var seenImportedIds = Set<String>()

        for transaction in imported where !seenImportedIds.contains(transaction.id) {
            seenImportedIds.insert(transaction.id)
            let signature = transactionMergeSignature(transaction)
            let importedUpdatedAt = payload.transactionUpdatedAtById?[transaction.id] ?? payload.exportedAt

            if let sameId = existing.first(where: { $0.id == transaction.id }) {
                let existingUpdatedAt = existingUpdatedAtById[sameId.id] ?? .distantPast
                if importedUpdatedAt >= existingUpdatedAt {
                    var merged = transaction
                    merged = Transaction(
                        id: sameId.id,
                        type: transaction.type,
                        category: transaction.category,
                        amount: transaction.amount,
                        date: transaction.date,
                        title: transaction.title,
                        notes: transaction.notes,
                        items: transaction.items,
                        location: transaction.location,
                        tags: transaction.tags,
                        currency: transaction.currency
                    )
                    try await transactionRepository.update(merged)
                }
            } else if let copy = existing.first(where: { transactionMergeSignature($0) == signature }) {
                // Same transaction content with different id -> merge into existing and avoid creating copy.
                let merged = Transaction(
                    id: copy.id,
                    type: transaction.type,
                    category: transaction.category,
                    amount: transaction.amount,
                    date: transaction.date,
                    title: transaction.title,
                    notes: transaction.notes,
                    items: transaction.items,
                    location: transaction.location,
                    tags: transaction.tags,
                    currency: transaction.currency
                )
                try await transactionRepository.update(merged)
            } else {
                try await transactionRepository.update(transaction)
            }

            existing = try await transactionRepository.fetchAll()
            try await deleteTransactionCopies(in: existing)
            existing = try await transactionRepository.fetchAll()
        }
    }

    private func mergeRecurringOneByOne(_ imported: [RecurringTransaction], payload: BackupPayload) async throws {
        var existing = try await recurringRepository.fetchAll()
        let existingUpdatedAtById = try await recurringRepository.updatedAtById()
        var seenImportedIds = Set<UUID>()

        for recurring in imported where !seenImportedIds.contains(recurring.id) {
            seenImportedIds.insert(recurring.id)
            let signature = recurringMergeSignature(recurring)
            let importedUpdatedAt = payload.recurringUpdatedAtById?[recurring.id.uuidString] ?? payload.exportedAt

            if existing.contains(where: { $0.id == recurring.id }) {
                let existingUpdatedAt = existingUpdatedAtById[recurring.id] ?? .distantPast
                if importedUpdatedAt >= existingUpdatedAt {
                    try await recurringRepository.upsert(recurring)
                }
            } else if let copy = existing.first(where: { recurringMergeSignature($0) == signature }) {
                // Same recurring rule with different id -> keep existing id and update values.
                let merged = RecurringTransaction(
                    id: copy.id,
                    title: recurring.title,
                    type: recurring.type,
                    categoryIdentifier: recurring.categoryIdentifier,
                    amount: recurring.amount,
                    startDate: recurring.startDate,
                    endDate: recurring.endDate,
                    recurrence: recurring.recurrence,
                    nextOccurrence: recurring.nextOccurrence,
                    lastTransactionAddedOn: recurring.lastTransactionAddedOn,
                    state: recurring.state,
                    notificationReminderEnabled: recurring.notificationReminderEnabled,
                    notificationReminderOffsetFromEndOfDay: recurring.notificationReminderOffsetFromEndOfDay,
                    notificationScheduledForOccurrenceDate: recurring.notificationScheduledForOccurrenceDate,
                    metadata: recurring.metadata
                )
                try await recurringRepository.upsert(merged)
            } else {
                try await recurringRepository.upsert(recurring)
            }

            existing = try await recurringRepository.fetchAll()
            try await deleteRecurringCopies(in: existing)
            existing = try await recurringRepository.fetchAll()
        }
    }

    private func deleteTransactionCopies(in transactions: [Transaction]) async throws {
        var seen = Set<String>()
        for transaction in transactions {
            let signature = transactionMergeSignature(transaction)
            if seen.contains(signature) {
                try await transactionRepository.delete(transaction)
            } else {
                seen.insert(signature)
            }
        }
    }

    private func deleteRecurringCopies(in recurring: [RecurringTransaction]) async throws {
        var seen = Set<String>()
        for item in recurring {
            let signature = recurringMergeSignature(item)
            if seen.contains(signature) {
                try await recurringRepository.delete(id: item.id)
            } else {
                seen.insert(signature)
            }
        }
    }

    private func transactionMergeSignature(_ transaction: Transaction) -> String {
        let itemsHash = transaction.items
            .map { "\($0.name)|\($0.quantity)|\($0.unitPrice)|\($0.totalPrice ?? 0)" }
            .joined(separator: ";")
        let tags = transaction.tags.sorted().joined(separator: "|")
        return [
            transaction.type.rawValue,
            transaction.category.rawValue,
            "\(transaction.amount)",
            "\(transaction.date)",
            transaction.title,
            transaction.notes ?? "",
            transaction.location ?? "",
            tags,
            "\(transaction.currency.id)",
            itemsHash
        ].joined(separator: "||")
    }

    private func recurringMergeSignature(_ recurring: RecurringTransaction) -> String {
        let recurrenceRaw: String = {
            guard let data = try? JSONEncoder().encode(recurring.recurrence),
                  let text = String(data: data, encoding: .utf8) else {
                return ""
            }
            return text
        }()
        let metadata = (recurring.metadata ?? [:])
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "|")
        return [
            recurring.title,
            recurring.type,
            recurring.categoryIdentifier ?? "",
            NSDecimalNumber(decimal: recurring.amount).stringValue,
            ISO8601DateFormatter().string(from: recurring.startDate),
            recurring.endDate.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            recurrenceRaw,
            recurring.nextOccurrence.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            recurring.state.rawValue,
            "\(recurring.notificationReminderEnabled)",
            recurring.notificationReminderOffsetFromEndOfDay.map { String($0) } ?? "",
            recurring.notificationScheduledForOccurrenceDate.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            metadata
        ].joined(separator: "||")
    }

    private func scheduleSuggestionRebuildAfterImport() {
        Task(priority: .utility) {
            guard let transactions = try? await transactionRepository.fetchAll() else {
                return
            }

            await MainActor.run {
                let engine = SuggestionEngine()
                engine.load()
                engine.rebuildFromRecentTransactions(
                    transactions,
                    monthsBack: SuggestionEngine.importRebuildLookbackMonths
                )
            }
        }
    }
}

private struct BackupPayload: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let settings: BackupSettings?
    let transactionUpdatedAtById: [String: Date]?
    let recurringUpdatedAtById: [String: Date]?
    let transactions: [Transaction]
    let recurringTransactions: [RecurringTransaction]
}

private struct BackupSettings: Codable {
    let selectedCurrencyCode: String?
}
