//
//  SwiftDataRecurringRepository.swift
//  Xpnse
//
//  Created by Gokul C on 04/05/26.
//

import Foundation
import SwiftData

/// Protocol defining operations for recurring transactions repository.
protocol RecurringRepository {
    /// Fetches all recurring transactions.
    func fetchAll() async throws -> [RecurringTransaction]
    func updatedAtById() async throws -> [UUID: Date]

    /// Inserts or updates a recurring transaction.
    func upsert(_ item: RecurringTransaction) async throws

    /// Deletes a recurring transaction by id.
    func delete(id: UUID) async throws

    /// Clears all recurring transactions.
    func clearAll() async throws
}

/// SwiftData-backed implementation of `RecurringRepository`.
final class SwiftDataRecurringRepository: RecurringRepository {
    static let shared: SwiftDataRecurringRepository = SwiftDataRecurringRepository()
    private let container: ModelContainer

    init(container: ModelContainer = SwiftDataStack.sharedContainer) {
        self.container = container
    }

    @MainActor
    private func context() -> ModelContext {
        ModelContext(container)
    }

    @MainActor
    func fetchAll() async throws -> [RecurringTransaction] {
        let context = context()
        let descriptor = FetchDescriptor<RecurringTransactionEntity>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        return try context.fetch(descriptor).compactMap { $0.toDomain() }
    }

    @MainActor
    func updatedAtById() async throws -> [UUID: Date] {
        let context = context()
        let descriptor = FetchDescriptor<RecurringTransactionEntity>()
        let all = try context.fetch(descriptor)
        return Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.updatedAt) })
    }

    @MainActor
    func upsert(_ item: RecurringTransaction) async throws {
        let context = context()
        let descriptor = FetchDescriptor<RecurringTransactionEntity>(
            predicate: #Predicate { $0.id == item.id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: item)
        } else {
            context.insert(RecurringTransactionEntity(from: item))
        }
        try context.save()
    }

    @MainActor
    func delete(id: UUID) async throws {
        let context = context()
        let descriptor = FetchDescriptor<RecurringTransactionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }

    @MainActor
    func clearAll() async throws {
        let context = context()
        let descriptor = FetchDescriptor<RecurringTransactionEntity>()
        let all = try context.fetch(descriptor)
        all.forEach { context.delete($0) }
        try context.save()
    }
}

// Backward compatible alias while migration is in progress.
typealias FirestoreRecurringRepository = SwiftDataRecurringRepository
