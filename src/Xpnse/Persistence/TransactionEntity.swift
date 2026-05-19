//
//  TransactionEntity.swift
//  Xpnse
//
//  Created by Gokul C on 04/05/26.
//

import Foundation
import SwiftData

@Model
final class TransactionEntity {
    @Attribute(.unique) var id: String
    var typeRawValue: String
    var categoryRawValue: String
    var amount: Double
    var date: Double
    var title: String
    var notes: String?
    var location: String?
    var tagsData: Data
    var itemsData: Data
    var currencyId: Int
    var currencyCode: String
    var currencyName: String
    var currencySymbol: String
    var recurringSeriesId: String?
    var recurringOccurrenceDate: Double?
    var createdAt: Date
    var updatedAt: Date

    init(from transaction: Transaction) {
        self.id = transaction.id
        self.typeRawValue = transaction.type.rawValue
        self.categoryRawValue = transaction.categoryId
        self.amount = transaction.amount
        self.date = transaction.date
        self.title = transaction.title
        self.notes = transaction.notes
        self.location = transaction.location
        self.tagsData = (try? JSONEncoder().encode(transaction.tags)) ?? Data()
        self.itemsData = (try? JSONEncoder().encode(transaction.items)) ?? Data()
        self.currencyId = transaction.currency.id
        self.currencyCode = transaction.currency.code
        self.currencyName = transaction.currency.name
        self.currencySymbol = transaction.currency.symbol
        self.recurringSeriesId = transaction.recurringSeriesId
        self.recurringOccurrenceDate = transaction.recurringOccurrenceDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func update(from transaction: Transaction) {
        self.typeRawValue = transaction.type.rawValue
        self.categoryRawValue = transaction.categoryId
        self.amount = transaction.amount
        self.date = transaction.date
        self.title = transaction.title
        self.notes = transaction.notes
        self.location = transaction.location
        self.tagsData = (try? JSONEncoder().encode(transaction.tags)) ?? Data()
        self.itemsData = (try? JSONEncoder().encode(transaction.items)) ?? Data()
        self.currencyId = transaction.currency.id
        self.currencyCode = transaction.currency.code
        self.currencyName = transaction.currency.name
        self.currencySymbol = transaction.currency.symbol
        self.recurringSeriesId = transaction.recurringSeriesId
        self.recurringOccurrenceDate = transaction.recurringOccurrenceDate
        self.updatedAt = Date()
    }

    func toDomain() -> Transaction {
        let type = TransactionType(rawValue: typeRawValue) ?? .expense
        let categoryId = categoryRawValue.isEmpty ? BuiltinCategories.otherCategoryId : categoryRawValue
        let items = (try? JSONDecoder().decode([TransactionItem].self, from: itemsData)) ?? []
        let tags = (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        let currency = CurrencyOption(
            id: currencyId,
            code: currencyCode,
            name: currencyName,
            symbol: currencySymbol
        )

        return Transaction(
            id: id,
            type: type,
            categoryId: categoryId,
            amount: amount,
            date: date,
            title: title,
            notes: notes,
            items: items,
            location: location,
            tags: tags,
            currency: currency,
            recurringSeriesId: recurringSeriesId,
            recurringOccurrenceDate: recurringOccurrenceDate
        )
    }
}
