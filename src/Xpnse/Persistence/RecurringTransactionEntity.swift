//
//  RecurringTransactionEntity.swift
//  Xpnse
//
//  Created by Gokul C on 04/05/26.
//

import Foundation
import SwiftData

@Model
final class RecurringTransactionEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var type: String
    var categoryIdentifier: String?
    var amountString: String
    var startDate: Date
    var endDate: Date?
    var recurrenceData: Data
    var nextOccurrence: Date?
    var lastTransactionAddedOn: Date?
    var metadataData: Data?
    var updatedAt: Date

    init(from recurringTransaction: RecurringTransaction) {
        self.id = recurringTransaction.id
        self.title = recurringTransaction.title
        self.type = recurringTransaction.type
        self.categoryIdentifier = recurringTransaction.categoryIdentifier
        self.amountString = NSDecimalNumber(decimal: recurringTransaction.amount).stringValue
        self.startDate = recurringTransaction.startDate
        self.endDate = recurringTransaction.endDate
        self.recurrenceData = (try? JSONEncoder().encode(recurringTransaction.recurrence)) ?? Data()
        self.nextOccurrence = recurringTransaction.nextOccurrence
        self.lastTransactionAddedOn = recurringTransaction.lastTransactionAddedOn
        self.metadataData = try? JSONEncoder().encode(recurringTransaction.metadata ?? [:])
        self.updatedAt = Date()
    }

    func update(from recurringTransaction: RecurringTransaction) {
        self.title = recurringTransaction.title
        self.type = recurringTransaction.type
        self.categoryIdentifier = recurringTransaction.categoryIdentifier
        self.amountString = NSDecimalNumber(decimal: recurringTransaction.amount).stringValue
        self.startDate = recurringTransaction.startDate
        self.endDate = recurringTransaction.endDate
        self.recurrenceData = (try? JSONEncoder().encode(recurringTransaction.recurrence)) ?? Data()
        self.nextOccurrence = recurringTransaction.nextOccurrence
        self.lastTransactionAddedOn = recurringTransaction.lastTransactionAddedOn
        self.metadataData = try? JSONEncoder().encode(recurringTransaction.metadata ?? [:])
        self.updatedAt = Date()
    }

    func toDomain() -> RecurringTransaction? {
        guard let recurrence = try? JSONDecoder().decode(RecurrenceFrequency.self, from: recurrenceData) else {
            return nil
        }

        let metadata = metadataData.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
        let amount = Decimal(string: amountString) ?? 0

        return RecurringTransaction(
            id: id,
            title: title,
            type: type,
            categoryIdentifier: categoryIdentifier,
            amount: amount,
            startDate: startDate,
            endDate: endDate,
            recurrence: recurrence,
            nextOccurrence: nextOccurrence,
            lastTransactionAddedOn: lastTransactionAddedOn,
            metadata: metadata
        )
    }
}
