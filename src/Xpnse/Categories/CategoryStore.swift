//
//  CategoryStore.swift
//  Xpnse
//

import Foundation
import Observation

@MainActor
@Observable
final class CategoryStore {
    static let shared = CategoryStore()

    private(set) var categories: [CategoryDefinition] = []

    private let repository: CategoryRepository
    private let transactionRepository: TransactionRepository

    init(
        repository: CategoryRepository = SwiftDataCategoryRepository.shared,
        transactionRepository: TransactionRepository = SwiftDataTransactionRepository.shared
    ) {
        self.repository = repository
        self.transactionRepository = transactionRepository
    }

    func load() async {
        do {
            var loaded = try await repository.fetchAll()
            if loaded.isEmpty {
                for seed in BuiltinCategories.seedDefinitions() {
                    try await repository.upsert(seed)
                }
                loaded = try await repository.fetchAll()
            }
            categories = try await migrateMissingColorsIfNeeded(loaded)
        } catch {
            categories = BuiltinCategories.seedDefinitions()
        }
    }

    private func migrateMissingColorsIfNeeded(_ loaded: [CategoryDefinition]) async throws -> [CategoryDefinition] {
        var migrated: [CategoryDefinition] = []
        var didChange = false

        for var category in loaded {
            let normalized = CategoryColorPalette.normalizedHex(category.colorHex)
            if normalized.isEmpty || !CategoryColorPalette.isValid(normalized) {
                let fallback = BuiltinCategories.defaultColorHex(for: category.id)
                    ?? CategoryColorPalette.defaultHex(for: category.transactionType)
                category.colorHex = fallback
                didChange = true
            } else if normalized != category.colorHex {
                category.colorHex = normalized
                didChange = true
            }
            migrated.append(category)
        }

        if didChange {
            for category in migrated {
                try await repository.upsert(category)
            }
        }
        return migrated
    }

    func categories(for type: TransactionType, includeDeleted: Bool = false) -> [CategoryDefinition] {
        categories
            .filter { category in
                (includeDeleted || !category.isDeleted)
                    && (category.transactionType == type || category.id == BuiltinCategories.otherCategoryId)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func allCategories(includeDeleted: Bool = true) -> [CategoryDefinition] {
        categories
            .filter { includeDeleted || !$0.isDeleted }
            .sorted { lhs, rhs in
                if lhs.transactionType != rhs.transactionType {
                    return lhs.transactionType == .expense
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    func resolve(id: String) -> CategoryDefinition {
        if let match = categories.first(where: { $0.id == id }) {
            return match
        }
        if let other = categories.first(where: { $0.id == BuiltinCategories.otherCategoryId }) {
            return other
        }
        return CategoryDefinition(
            id: id,
            name: "Unknown",
            symbolName: "questionmark.circle",
            colorHex: CategoryColorPalette.defaultHex,
            transactionType: .expense,
            isBuiltIn: false,
            isDeleted: true
        )
    }

    func categoryDisplayName(for id: String) -> String {
        resolve(id: id).name
    }

    func categorySymbolName(for id: String) -> String {
        resolve(id: id).symbolName
    }

    func categoryColorHex(for id: String) -> String {
        resolve(id: id).colorHex
    }

    func add(
        name: String,
        symbolName: String,
        colorHex: String,
        transactionType: TransactionType
    ) async throws {
        let maxOrder = categories
            .filter { $0.transactionType == transactionType && !$0.isDeleted }
            .map(\.sortOrder)
            .max() ?? -1
        let resolvedColor = CategoryColorPalette.isValid(colorHex)
            ? CategoryColorPalette.normalizedHex(colorHex)
            : CategoryColorPalette.defaultHex(for: transactionType)
        let definition = CategoryDefinition(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            symbolName: symbolName,
            colorHex: resolvedColor,
            transactionType: transactionType,
            isBuiltIn: false,
            sortOrder: maxOrder + 1
        )
        try await repository.upsert(definition)
        await load()
    }

    func update(_ definition: CategoryDefinition) async throws {
        guard let existing = categories.first(where: { $0.id == definition.id }) else { return }
        if existing.isDeletionProtected {
            var updated = definition
            updated.id = existing.id
            updated.isDeletionProtected = true
            updated.isBuiltIn = existing.isBuiltIn
            updated.updatedAt = Date()
            try await repository.upsert(updated)
        } else {
            var updated = definition
            updated.updatedAt = Date()
            if existing.isBuiltIn {
                updated.isBuiltIn = true
            }
            try await repository.upsert(updated)
        }
        await load()
    }

    func canChangeTransactionType(categoryId: String) async -> Bool {
        guard let category = categories.first(where: { $0.id == categoryId }) else { return false }
        if category.isBuiltIn { return false }
        let count = (try? await repository.usageCount(for: categoryId)) ?? 0
        return count == 0
    }

    func softDelete(id: String) async throws {
        guard var category = categories.first(where: { $0.id == id }) else { return }
        guard !category.isDeletionProtected else {
            throw CategoryStoreError.cannotDeleteProtected
        }
        category.isDeleted = true
        category.updatedAt = Date()
        try await repository.upsert(category)
        try await repository.reassignTransactions(
            from: id,
            to: BuiltinCategories.otherCategoryId
        )
        try await repository.reassignRecurring(
            from: id,
            to: BuiltinCategories.otherCategoryId
        )
        await load()
    }

    func applyImported(_ imported: [CategoryDefinition]) async throws {
        for category in imported {
            try await repository.upsert(category)
        }
        await load()
    }

    func fetchAllForExport() async throws -> [CategoryDefinition] {
        try await repository.fetchAll()
    }

    func updatedAtById() async throws -> [String: Date] {
        try await repository.updatedAtById()
    }

    func upsertFromImport(_ category: CategoryDefinition) async throws {
        try await repository.upsert(category)
    }

    /// Maps an unknown category id from bill scan to a valid id or `other`.
    func mapScannedCategoryId(_ rawId: String, transactionType: TransactionType) -> String {
        let trimmed = rawId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let active = categories(for: transactionType)
        if active.contains(where: { $0.id == trimmed }) {
            return trimmed
        }
        if let byName = active.first(where: { $0.name.lowercased() == trimmed }) {
            return byName.id
        }
        return BuiltinCategories.otherCategoryId
    }

    func categoryGuideDescription(for transactionType: TransactionType) -> String {
        let active = categories(for: transactionType)
        let list = active.map { "\($0.id)=\($0.name)" }.joined(separator: ", ")
        return "Category id. Must be one of: \(list). Use '\(BuiltinCategories.otherCategoryId)' if unsure."
    }
}

enum CategoryStoreError: LocalizedError {
    case cannotDeleteProtected
    case emptyName

    var errorDescription: String? {
        switch self {
        case .cannotDeleteProtected:
            return "This category cannot be deleted."
        case .emptyName:
            return "Category name cannot be empty."
        }
    }
}
