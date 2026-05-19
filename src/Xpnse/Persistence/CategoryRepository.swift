//
//  CategoryRepository.swift
//  Xpnse
//

import Foundation
import SwiftData

protocol CategoryRepository {
    func fetchAll() async throws -> [CategoryDefinition]
    func updatedAtById() async throws -> [String: Date]
    func upsert(_ category: CategoryDefinition) async throws
    func clearAll() async throws
    func reassignTransactions(from oldId: String, to newId: String) async throws
    func reassignRecurring(from oldId: String, to newId: String) async throws
    func usageCount(for categoryId: String) async throws -> Int
}

final class SwiftDataCategoryRepository: CategoryRepository {
    static let shared = SwiftDataCategoryRepository()

    private let container: ModelContainer

    init(container: ModelContainer = SwiftDataStack.sharedContainer) {
        self.container = container
    }

    @MainActor
    private func context() -> ModelContext {
        ModelContext(container)
    }

    @MainActor
    func fetchAll() async throws -> [CategoryDefinition] {
        let context = context()
        let descriptor = FetchDescriptor<CategoryEntity>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    @MainActor
    func updatedAtById() async throws -> [String: Date] {
        let context = context()
        let descriptor = FetchDescriptor<CategoryEntity>()
        let all = try context.fetch(descriptor)
        return Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.updatedAt) })
    }

    @MainActor
    func upsert(_ category: CategoryDefinition) async throws {
        let context = context()
        let descriptor = FetchDescriptor<CategoryEntity>(
            predicate: #Predicate { $0.id == category.id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: category)
        } else {
            context.insert(CategoryEntity(from: category))
        }
        try context.save()
    }

    @MainActor
    func clearAll() async throws {
        let context = context()
        let descriptor = FetchDescriptor<CategoryEntity>()
        let all = try context.fetch(descriptor)
        all.forEach { context.delete($0) }
        try context.save()
    }

    @MainActor
    func reassignTransactions(from oldId: String, to newId: String) async throws {
        let context = context()
        let descriptor = FetchDescriptor<TransactionEntity>(
            predicate: #Predicate { $0.categoryRawValue == oldId }
        )
        let matches = try context.fetch(descriptor)
        for entity in matches {
            entity.categoryRawValue = newId
            entity.updatedAt = Date()
        }
        if !matches.isEmpty {
            try context.save()
        }
    }

    @MainActor
    func reassignRecurring(from oldId: String, to newId: String) async throws {
        let context = context()
        let descriptor = FetchDescriptor<RecurringTransactionEntity>(
            predicate: #Predicate { $0.categoryIdentifier == oldId }
        )
        let matches = try context.fetch(descriptor)
        for entity in matches {
            entity.categoryIdentifier = newId
            entity.updatedAt = Date()
        }
        if !matches.isEmpty {
            try context.save()
        }
    }

    @MainActor
    func usageCount(for categoryId: String) async throws -> Int {
        let context = context()
        let txnDescriptor = FetchDescriptor<TransactionEntity>(
            predicate: #Predicate { $0.categoryRawValue == categoryId }
        )
        let recurringDescriptor = FetchDescriptor<RecurringTransactionEntity>(
            predicate: #Predicate { $0.categoryIdentifier == categoryId }
        )
        let txnCount = try context.fetch(txnDescriptor).count
        let recurringCount = try context.fetch(recurringDescriptor).count
        return txnCount + recurringCount
    }
}
