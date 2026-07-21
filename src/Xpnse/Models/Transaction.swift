//
//  Transaction.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation

// MARK: - Transaction
struct Transaction: Identifiable, Codable, Equatable, Hashable {
    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case categoryId
        case category
        case amount
        case date
        case title
        case merchant
        case notes
        case items
        case location
        case tags
        case currency
        case recurringSeriesId
        case recurringOccurrenceDate
    }

    let id: String
    var type: TransactionType
    var categoryId: String
    var amount: Double
    var date: Double
    var title: String
    var merchant: String?
    var notes: String?
    var items: [TransactionItem]
    var location: String?
    var tags: [String]
    var currency: CurrencyOption
    var recurringSeriesId: String?
    var recurringOccurrenceDate: Double?

    var isRecurringGenerated: Bool {
        recurringSeriesId != nil
    }

    var categoryDisplayName: String {
        CategoryStore.shared.categoryDisplayName(for: categoryId)
    }

    var categorySymbolName: String {
        CategoryStore.shared.categorySymbolName(for: categoryId)
    }

    var categoryColorHex: String {
        CategoryStore.shared.categoryColorHex(for: categoryId)
    }

    // Computed properties
    var totalAmount: Double {
        guard amount <= 0 else { return amount }
        if !items.isEmpty {
            return items.reduce(0) { $0 + ($1.totalPrice ?? 0.0) }
        }
        return 0.0
    }

    var formattedDate: String {
        let formattedDate = Date(timeIntervalSince1970: date)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: formattedDate)
    }

    var formattedAmount: String {
        AmountFormatter.format(totalAmount)
    }

    init(
        id: String,
        type: TransactionType,
        categoryId: String,
        amount: Double,
        date: Double = Date().timeIntervalSince1970,
        title: String,
        merchant: String? = nil,
        notes: String? = nil,
        items: [TransactionItem] = [],
        location: String? = nil,
        tags: [String] = [],
        currency: CurrencyOption = CurrencyManager.shared.selectedCurrency,
        recurringSeriesId: String? = nil,
        recurringOccurrenceDate: Double? = nil
    ) {
        self.id = id
        self.type = type
        self.categoryId = categoryId
        self.amount = amount
        self.date = date
        self.title = title
        self.merchant = merchant
        self.notes = notes
        self.items = items
        self.location = location
        self.tags = tags
        self.currency = currency
        self.recurringSeriesId = recurringSeriesId
        self.recurringOccurrenceDate = recurringOccurrenceDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(TransactionType.self, forKey: .type)
        if let decodedId = try container.decodeIfPresent(String.self, forKey: .categoryId) {
            categoryId = decodedId
        } else if let legacy = try container.decodeIfPresent(String.self, forKey: .category) {
            categoryId = legacy
        } else {
            categoryId = BuiltinCategories.otherCategoryId
        }
        amount = try container.decode(Double.self, forKey: .amount)
        date = try container.decode(Double.self, forKey: .date)
        title = try container.decode(String.self, forKey: .title)
        merchant = try container.decodeIfPresent(String.self, forKey: .merchant)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        items = try container.decodeIfPresent([TransactionItem].self, forKey: .items) ?? []
        location = try container.decodeIfPresent(String.self, forKey: .location)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        currency = try container.decodeIfPresent(CurrencyOption.self, forKey: .currency) ?? CurrencyManager.shared.selectedCurrency
        recurringSeriesId = try container.decodeIfPresent(String.self, forKey: .recurringSeriesId)
        recurringOccurrenceDate = try container.decodeIfPresent(Double.self, forKey: .recurringOccurrenceDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(amount, forKey: .amount)
        try container.encode(date, forKey: .date)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(merchant, forKey: .merchant)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(tags, forKey: .tags)
        try container.encode(currency, forKey: .currency)
        try container.encodeIfPresent(recurringSeriesId, forKey: .recurringSeriesId)
        try container.encodeIfPresent(recurringOccurrenceDate, forKey: .recurringOccurrenceDate)
    }

    // MARK: - Firebase Conversion

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "type": type.rawValue,
            "category": categoryId,
            "amount": amount,
            "date": Int(date),
            "title": title,
            "tags": tags,
            "currency_id": currency.id,
            "currency_symbol": currency.symbol
        ]

        if let merchant = merchant {
            data["merchant"] = merchant
        }

        if let notes = notes {
            data["notes"] = notes
        }

        if let location = location {
            data["location"] = location
        }

        data["items"] = items.map { item in
            [
                "id": item.id.uuidString,
                "name": item.name,
                "quantity": item.quantity,
                "unitPrice": item.unitPrice
            ]
        }

        return data
    }

    static func fromFirestoreData(_ data: [String: Any]) -> Transaction? {
        guard let idString = data["id"] as? String,
              UUID(uuidString: idString) != nil,
              let typeString = data["type"] as? String,
              let type = TransactionType(rawValue: typeString),
              let categoryString = data["category"] as? String,
              let title = data["title"] as? String,
              let amount = data["amount"] as? Double,
              let currencyId = data["currency_id"] as? Int else {
            return nil
        }

        let date: Date
        if let timestamp = data["date"] as? Date {
            date = timestamp
        } else {
            date = Date()
        }

        let items: [TransactionItem] = (data["items"] as? [[String: Any]])?.compactMap { itemData in
            guard let name = itemData["name"] as? String,
                  let quantity = itemData["quantity"] as? Double,
                  let unitPrice = itemData["unitPrice"] as? Double else {
                return nil
            }
            return TransactionItem(name: name, quantity: quantity, unitPrice: unitPrice)
        } ?? []

        return Transaction(
            id: idString,
            type: type,
            categoryId: categoryString,
            amount: amount,
            date: date.timeIntervalSince1970,
            title: title,
            merchant: data["merchant"] as? String,
            notes: data["notes"] as? String,
            items: items,
            location: data["location"] as? String,
            tags: data["tags"] as? [String] ?? [],
            currency: CurrencyManager.shared.currencies.first(where: { $0.id == currencyId }) ?? CurrencyManager.shared.selectedCurrency
        )
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
