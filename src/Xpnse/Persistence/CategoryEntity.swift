//
//  CategoryEntity.swift
//  Xpnse
//

import Foundation
import SwiftData

@Model
final class CategoryEntity {
    @Attribute(.unique) var id: String
    var name: String
    var symbolName: String
    var colorHex: String?
    var transactionTypeRaw: String
    var isBuiltIn: Bool
    var isDeleted: Bool
    var isDeletionProtected: Bool
    var sortOrder: Int
    var updatedAt: Date

    init(from definition: CategoryDefinition) {
        self.id = definition.id
        self.name = definition.name
        self.symbolName = definition.symbolName
        self.colorHex = CategoryColorPalette.normalizedHex(definition.colorHex)
        self.transactionTypeRaw = definition.transactionType.rawValue
        self.isBuiltIn = definition.isBuiltIn
        self.isDeleted = definition.isDeleted
        self.isDeletionProtected = definition.isDeletionProtected
        self.sortOrder = definition.sortOrder
        self.updatedAt = definition.updatedAt
    }

    func update(from definition: CategoryDefinition) {
        self.name = definition.name
        self.symbolName = definition.symbolName
        self.colorHex = CategoryColorPalette.normalizedHex(definition.colorHex)
        self.transactionTypeRaw = definition.transactionType.rawValue
        self.isBuiltIn = definition.isBuiltIn
        self.isDeleted = definition.isDeleted
        self.isDeletionProtected = definition.isDeletionProtected
        self.sortOrder = definition.sortOrder
        self.updatedAt = definition.updatedAt
    }

    func toDomain() -> CategoryDefinition {
        let resolvedHex: String = {
            let stored = (colorHex ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !stored.isEmpty {
                return CategoryColorPalette.normalizedHex(stored)
            }
            return BuiltinCategories.defaultColorHex(for: id)
                ?? CategoryColorPalette.defaultHex(
                    for: TransactionType(rawValue: transactionTypeRaw) ?? .expense
                )
        }()

        return CategoryDefinition(
            id: id,
            name: name,
            symbolName: symbolName,
            colorHex: resolvedHex,
            transactionType: TransactionType(rawValue: transactionTypeRaw) ?? .expense,
            isBuiltIn: isBuiltIn,
            isDeleted: isDeleted,
            isDeletionProtected: isDeletionProtected,
            sortOrder: sortOrder,
            updatedAt: updatedAt
        )
    }
}
