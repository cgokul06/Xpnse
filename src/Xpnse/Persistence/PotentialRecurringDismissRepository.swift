//
//  PotentialRecurringDismissRepository.swift
//  Xpnse
//

import Foundation
import SwiftData

protocol PotentialRecurringDismissRepository {
    func fetchAll() async throws -> [PotentialRecurringDismissRecord]
    func upsert(_ record: PotentialRecurringDismissRecord) async throws
    func clearAll() async throws
}

final class SwiftDataPotentialRecurringDismissRepository: PotentialRecurringDismissRepository {
    static let shared = SwiftDataPotentialRecurringDismissRepository()

    private let container: ModelContainer

    init(container: ModelContainer = SwiftDataStack.sharedContainer) {
        self.container = container
    }

    @MainActor
    private func context() -> ModelContext {
        ModelContext(container)
    }

    @MainActor
    func fetchAll() async throws -> [PotentialRecurringDismissRecord] {
        let context = context()
        let descriptor = FetchDescriptor<PotentialRecurringDismissEntity>(
            sortBy: [SortDescriptor(\.dismissedAt, order: .forward)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    @MainActor
    func upsert(_ record: PotentialRecurringDismissRecord) async throws {
        let context = context()
        let id = record.id
        let transactionId = record.transactionId
        let fingerprint = record.fingerprint

        let byId = FetchDescriptor<PotentialRecurringDismissEntity>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(byId).first {
            existing.update(from: record)
            try context.save()
            return
        }

        // Collapse duplicates that match the same transaction or fingerprint.
        let matches = FetchDescriptor<PotentialRecurringDismissEntity>(
            predicate: #Predicate {
                $0.transactionId == transactionId || $0.fingerprint == fingerprint
            }
        )
        let existingMatches = try context.fetch(matches)
        if let first = existingMatches.first {
            first.update(from: record)
            for extra in existingMatches.dropFirst() {
                context.delete(extra)
            }
            try context.save()
            return
        }

        context.insert(PotentialRecurringDismissEntity(from: record))
        try context.save()
    }

    @MainActor
    func clearAll() async throws {
        let context = context()
        let descriptor = FetchDescriptor<PotentialRecurringDismissEntity>()
        let all = try context.fetch(descriptor)
        all.forEach { context.delete($0) }
        try context.save()
    }
}
