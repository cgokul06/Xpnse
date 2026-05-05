//
//  TransactionRepository.swift
//  Xpnse
//
//  Created by Gokul C on 04/05/26.
//

import Foundation
import SwiftData

protocol TransactionRepository {
    func add(_ transaction: Transaction) async throws
    func update(_ transaction: Transaction) async throws
    func delete(_ transaction: Transaction) async throws
    func fetch(startDate: Date, endDate: Date) async throws -> [Transaction]
    func fetchAll() async throws -> [Transaction]
    func clearAll() async throws
}

final class SwiftDataTransactionRepository: TransactionRepository {
    static let shared = SwiftDataTransactionRepository()

    private let container: ModelContainer

    init(container: ModelContainer = SwiftDataStack.sharedContainer) {
        self.container = container
    }

    @MainActor
    private func context() -> ModelContext {
        ModelContext(container)
    }

    @MainActor
    func add(_ transaction: Transaction) async throws {
        let context = context()
        let entity = TransactionEntity(from: transaction)
        context.insert(entity)
        try context.save()
    }

    @MainActor
    func update(_ transaction: Transaction) async throws {
        let context = context()
        let descriptor = FetchDescriptor<TransactionEntity>(
            predicate: #Predicate { $0.id == transaction.id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: transaction)
        } else {
            context.insert(TransactionEntity(from: transaction))
        }
        try context.save()
    }

    @MainActor
    func delete(_ transaction: Transaction) async throws {
        let context = context()
        let descriptor = FetchDescriptor<TransactionEntity>(
            predicate: #Predicate { $0.id == transaction.id }
        )
        guard let existing = try context.fetch(descriptor).first else { return }
        context.delete(existing)
        try context.save()
    }

    @MainActor
    func fetch(startDate: Date, endDate: Date) async throws -> [Transaction] {
        let context = context()
        let start = startDate.timeIntervalSince1970
        let end = endDate.timeIntervalSince1970
        let descriptor = FetchDescriptor<TransactionEntity>(
            predicate: #Predicate { entity in
                entity.date >= start && entity.date <= end
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    @MainActor
    func fetchAll() async throws -> [Transaction] {
        let context = context()
        let descriptor = FetchDescriptor<TransactionEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    @MainActor
    func clearAll() async throws {
        let context = context()
        let descriptor = FetchDescriptor<TransactionEntity>()
        let all = try context.fetch(descriptor)
        all.forEach { context.delete($0) }
        try context.save()
    }
}
