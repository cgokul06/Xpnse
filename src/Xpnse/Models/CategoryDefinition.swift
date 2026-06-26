//
//  CategoryDefinition.swift
//  Xpnse
//

import Foundation

struct CategoryDefinition: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var symbolName: String
    /// `#RRGGBB` hex color for UI and backup export/import.
    var colorHex: String
    var transactionType: TransactionType
    var isBuiltIn: Bool
    var isDeleted: Bool
    var isDeletionProtected: Bool
    var sortOrder: Int
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbolName
        case colorHex
        case transactionType
        case isBuiltIn
        case isDeleted
        case isDeletionProtected
        case sortOrder
        case updatedAt
    }

    init(
        id: String,
        name: String,
        symbolName: String,
        colorHex: String,
        transactionType: TransactionType,
        isBuiltIn: Bool = false,
        isDeleted: Bool = false,
        isDeletionProtected: Bool = false,
        sortOrder: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorHex = CategoryColorPalette.normalizedHex(colorHex)
        self.transactionType = transactionType
        self.isBuiltIn = isBuiltIn
        self.isDeleted = isDeleted
        self.isDeletionProtected = isDeletionProtected
        self.sortOrder = sortOrder
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbolName = try container.decode(String.self, forKey: .symbolName)
        transactionType = try container.decode(TransactionType.self, forKey: .transactionType)
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        isDeletionProtected = try container.decodeIfPresent(Bool.self, forKey: .isDeletionProtected) ?? false
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()

        if let decodedColor = try container.decodeIfPresent(String.self, forKey: .colorHex),
           !decodedColor.isEmpty {
            colorHex = CategoryColorPalette.normalizedHex(decodedColor)
        } else {
            colorHex = BuiltinCategories.defaultColorHex(for: id)
                ?? CategoryColorPalette.defaultHex(for: transactionType)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(symbolName, forKey: .symbolName)
        try container.encode(CategoryColorPalette.normalizedHex(colorHex), forKey: .colorHex)
        try container.encode(transactionType, forKey: .transactionType)
        try container.encode(isBuiltIn, forKey: .isBuiltIn)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(isDeletionProtected, forKey: .isDeletionProtected)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

enum BuiltinCategories {
    static let otherCategoryId = "other"

    private static let defaultColorsById: [String: String] = [
        "food": "#EF4444",
        "transport": "#0EA5E9",
        "shopping": "#8B5CF6",
        "health": "#EC4899",
        "bills": "#F59E0B",
        "other": "#9CA3AF",
        "salary": "#22C55E",
        "business": "#3B82F6",
        "gifts": "#FB7185",
        "rewards": "#EAB308",
        "investments": "#14B8A6"
    ]

    static func defaultColorHex(for id: String) -> String? {
        defaultColorsById[id]
    }

    static func seedDefinitions() -> [CategoryDefinition] {
        var order = 0
        func expense(
            _ id: String,
            _ name: String,
            _ symbol: String,
            _ colorHex: String,
            protected: Bool = false
        ) -> CategoryDefinition {
            defer { order += 1 }
            return CategoryDefinition(
                id: id,
                name: name,
                symbolName: symbol,
                colorHex: colorHex,
                transactionType: .expense,
                isBuiltIn: true,
                isDeletionProtected: protected,
                sortOrder: order
            )
        }
        func income(
            _ id: String,
            _ name: String,
            _ symbol: String,
            _ colorHex: String,
            protected: Bool = false
        ) -> CategoryDefinition {
            defer { order += 1 }
            return CategoryDefinition(
                id: id,
                name: name,
                symbolName: symbol,
                colorHex: colorHex,
                transactionType: .income,
                isBuiltIn: true,
                isDeletionProtected: protected,
                sortOrder: order
            )
        }

        return [
            expense("food", "Food", "fork.knife", "#EF4444"),
            expense("transport", "Transport", "car", "#0EA5E9"),
            expense("shopping", "Shopping", "bag", "#8B5CF6"),
            expense("health", "Health", "medical.thermometer", "#EC4899"),
            expense("bills", "Bills", "text.pad.header", "#F59E0B"),
            expense("other", "Other", "ellipsis.circle", "#9CA3AF", protected: true),
            income("salary", "Salary", "dollarsign.circle", "#22C55E"),
            income("business", "Business", "building.2", "#3B82F6"),
            income("gifts", "Gifts", "gift", "#FB7185"),
            income("rewards", "Rewards", "star.fill", "#EAB308"),
            income("investments", "Investments", "chart.bar", "#14B8A6")
        ]
    }

    static func seedById() -> [String: CategoryDefinition] {
        Dictionary(uniqueKeysWithValues: seedDefinitions().map { ($0.id, $0) })
    }

    static var builtInCategoryIds: Set<String> {
        Set(seedDefinitions().map(\.id))
    }
}
