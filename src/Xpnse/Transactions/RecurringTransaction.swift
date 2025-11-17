//
//  RecurringTransaction.swift
//  Xpnse
//
//  Created by Gokul C on 15/11/25.
//

import Foundation

/// A recurring financial transaction, with recurrence pattern and metadata.
public struct RecurringTransaction: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier.
    public var id: UUID
    /// Title or description of the transaction.
    public var title: String
    /// Type of transaction
    public var type: String
    /// Optional category identifier.
    public var categoryIdentifier: String?
    /// Amount of the transaction.
    public var amount: Decimal
    /// Start date of the recurrence.
    public var startDate: Date
    /// Optional end date of the recurrence.
    public var endDate: Date?
    /// Recurrence frequency pattern.
    public var recurrence: RecurrenceFrequency
    /// The next scheduled occurrence date, or nil if none.
    public var nextOccurrence: Date?
    /// Optional additional metadata.
    public var metadata: [String: String]?

    /// Memberwise initializer.
    public init(
        id: UUID,
        title: String,
        type: String,
        categoryIdentifier: String?,
        amount: Decimal,
        startDate: Date,
        endDate: Date?,
        recurrence: RecurrenceFrequency,
        nextOccurrence: Date?,
        metadata: [String: String]?
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.categoryIdentifier = categoryIdentifier
        self.amount = amount
        self.startDate = startDate
        self.endDate = endDate
        self.recurrence = recurrence
        self.nextOccurrence = nextOccurrence
        self.metadata = metadata
    }

    /// Convenience initializer that generates `id` and computes the first `nextOccurrence`.
    public init(
        title: String,
        type: String,
        categoryIdentifier: String? = nil,
        amount: Decimal,
        startDate: Date,
        endDate: Date? = nil,
        recurrence: RecurrenceFrequency,
        metadata: [String: String]? = nil,
        calendar: Calendar = .current
    ) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.categoryIdentifier = categoryIdentifier
        self.amount = amount
        self.startDate = startDate
        self.endDate = endDate
        self.recurrence = recurrence
        self.metadata = metadata
        self.nextOccurrence = recurrence.firstOccurrence(onOrAfter: startDate, calendar: calendar)
    }
}
