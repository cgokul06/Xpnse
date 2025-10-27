//
//  Transaction.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation

// MARK: - Transaction
struct Transaction: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var type: TransactionType
    var category: TransactionCategory
    var amount: Double
    var date: Double
    var title: String
    var notes: String?
    var items: [TransactionItem]
    var location: String?
    var tags: [String]
    var currency: CurrencyOption

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
        return String(format: "%.2f", totalAmount)
    }

    init(
        id: String,
        type: TransactionType,
        category: TransactionCategory,
        amount: Double,
        date: Double = Date().timeIntervalSince1970,
        title: String,
        notes: String? = nil,
        items: [TransactionItem] = [],
        location: String? = nil,
        tags: [String] = [],
        currency: CurrencyOption = CurrencyManager.shared.selectedCurrency
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.amount = amount
        self.date = date
        self.title = title
        self.notes = notes
        self.items = items
        self.location = location
        self.tags = tags
        self.currency = currency
    }

    // MARK: - Firebase Conversion

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "type": type.rawValue,
            "category": category.rawValue,
            "amount": amount,
            "date": Int(date),
            "title": title,
            "tags": tags,
            "currency_id": currency.id,
            "currency_symbol": currency.symbol
        ]

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
              let id = UUID(uuidString: idString),
              let typeString = data["type"] as? String,
              let type = TransactionType(rawValue: typeString),
              let categoryString = data["category"] as? String,
              let category = TransactionCategory(rawValue: categoryString),
              let title = data["title"] as? String,
              let amount = data["amount"] as? Double,
              let currencyId = data["currency_id"] as? Int else {
            return nil
        }

        // Parse date
        let date: Date
        if let timestamp = data["date"] as? Date {
            date = timestamp
        } else {
            date = Date()
        }

        // Parse items
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
            category: category,
            amount: amount,
            date: date.timeIntervalSince1970,
            title: title,
            notes: data["notes"] as? String,
            items: items,
            location: data["location"] as? String,
            tags: data["tags"] as? [String] ?? [],
            currency: CurrencyManager.shared.currencies.first(where: { $0.id == currencyId }) ?? CurrencyManager.shared.selectedCurrency
        )
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
