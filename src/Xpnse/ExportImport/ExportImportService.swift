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
    /// 6: includes user-editable category catalog in backup (`colorHex` as `#RRGGBB`).
    private static let currentSchemaVersion = 6

    private let transactionRepository: TransactionRepository
    private let recurringRepository: RecurringRepository
    private let categoryRepository: CategoryRepository

    init(
        transactionRepository: TransactionRepository = SwiftDataTransactionRepository.shared,
        recurringRepository: RecurringRepository = SwiftDataRecurringRepository.shared,
        categoryRepository: CategoryRepository = SwiftDataCategoryRepository.shared
    ) {
        self.transactionRepository = transactionRepository
        self.recurringRepository = recurringRepository
        self.categoryRepository = categoryRepository
    }

    func exportAllData() async throws -> String {
        let transactions = try await transactionRepository.fetchAll()
        let recurringTransactions = try await recurringRepository.fetchAll()
        let categories = try await categoryRepository.fetchAll()
        let categoryUpdatedAt = try await categoryRepository.updatedAtById()
        let categoryUpdatedAtById = Dictionary(
            uniqueKeysWithValues: categoryUpdatedAt.map { ($0.key, $0.value) }
        )
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
            categoryUpdatedAtById: categoryUpdatedAtById,
            transactionUpdatedAtById: try await transactionRepository.updatedAtById(),
            recurringUpdatedAtById: recurringUpdatedAtById,
            categories: categories,
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

        if let importedCategories = payload.categories, !importedCategories.isEmpty {
            try await mergeCategoriesOneByOne(importedCategories, payload: payload)
        } else {
            await CategoryStore.shared.load()
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

    private func mergeCategoriesOneByOne(_ imported: [CategoryDefinition], payload: BackupPayload) async throws {
        var existing = try await categoryRepository.fetchAll()
        let existingUpdatedAtById = try await categoryRepository.updatedAtById()
        var seenImportedIds = Set<String>()

        for category in imported where !seenImportedIds.contains(category.id) {
            seenImportedIds.insert(category.id)
            let importedUpdatedAt = payload.categoryUpdatedAtById?[category.id] ?? payload.exportedAt

            if existing.contains(where: { $0.id == category.id }) {
                let existingUpdatedAt = existingUpdatedAtById[category.id] ?? .distantPast
                if importedUpdatedAt >= existingUpdatedAt {
                    try await categoryRepository.upsert(category)
                }
            } else {
                try await categoryRepository.upsert(category)
            }

            existing = try await categoryRepository.fetchAll()
        }

        await CategoryStore.shared.load()
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
                    let merged = Transaction(
                        id: sameId.id,
                        type: transaction.type,
                        categoryId: transaction.categoryId,
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
                let merged = Transaction(
                    id: copy.id,
                    type: transaction.type,
                    categoryId: transaction.categoryId,
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
            transaction.categoryId,
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
    let categoryUpdatedAtById: [String: Date]?
    let transactionUpdatedAtById: [String: Date]?
    let recurringUpdatedAtById: [String: Date]?
    let categories: [CategoryDefinition]?
    let transactions: [Transaction]
    let recurringTransactions: [RecurringTransaction]
}

private struct BackupSettings: Codable {
    let selectedCurrencyCode: String?
}
