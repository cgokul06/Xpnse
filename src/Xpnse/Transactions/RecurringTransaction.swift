//
//  RecurringTransaction.swift
//  Xpnse
//
//  Created by Gokul C on 15/11/25.
//

import Foundation

public enum RecurringTransactionState: String, Codable, Hashable, Sendable {
    case active
    case paused
    case deleted
}

/// A recurring financial transaction, with recurrence pattern and metadata.
public struct RecurringTransaction: Codable, Identifiable, Hashable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case categoryIdentifier
        case amount
        case startDate
        case endDate
        case recurrence
        case nextOccurrence
        case lastTransactionAddedOn
        case state
        case metadata
    }
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
    /// Last date on which a transaction instance was materialized from this rule.
    public var lastTransactionAddedOn: Date?
    /// Operational state of recurring transaction lifecycle.
    public var state: RecurringTransactionState
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
        lastTransactionAddedOn: Date? = nil,
        state: RecurringTransactionState = .active,
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
        self.lastTransactionAddedOn = lastTransactionAddedOn
        self.state = state
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
        lastTransactionAddedOn: Date? = nil,
        state: RecurringTransactionState = .active,
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
        self.lastTransactionAddedOn = lastTransactionAddedOn
        self.state = state
        self.metadata = metadata
        self.nextOccurrence = recurrence.firstOccurrence(onOrAfter: startDate, calendar: calendar)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.type = try container.decode(String.self, forKey: .type)
        self.categoryIdentifier = try container.decodeIfPresent(String.self, forKey: .categoryIdentifier)
        self.amount = try container.decode(Decimal.self, forKey: .amount)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        self.recurrence = try container.decode(RecurrenceFrequency.self, forKey: .recurrence)
        self.nextOccurrence = try container.decodeIfPresent(Date.self, forKey: .nextOccurrence)
        self.lastTransactionAddedOn = try container.decodeIfPresent(Date.self, forKey: .lastTransactionAddedOn)
        self.state = try container.decodeIfPresent(RecurringTransactionState.self, forKey: .state) ?? .active
        self.metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
    }
}
