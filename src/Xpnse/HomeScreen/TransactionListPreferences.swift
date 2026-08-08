//
//  TransactionListPreferences.swift
//  Xpnse
//

import Foundation

/// Date sort for the home transaction list. Default matches historical newest-first behavior.
enum TransactionListSortOrder: String, CaseIterable, Hashable, Sendable {
    /// Oldest dates / times first.
    case ascending
    /// Newest dates / times first (current default).
    case descending

    var titleKey: String {
        switch self {
        case .descending: return "home.list_options.sort.descending"
        case .ascending: return "home.list_options.sort.ascending"
        }
    }

    func datesSorted(_ dates: [Date]) -> [Date] {
        switch self {
        case .descending: return dates.sorted(by: >)
        case .ascending: return dates.sorted(by: <)
        }
    }

    func transactionsSorted(_ transactions: [Transaction]) -> [Transaction] {
        switch self {
        case .descending: return transactions.sorted { $0.date > $1.date }
        case .ascending: return transactions.sorted { $0.date < $1.date }
        }
    }

    func upcomingSorted(_ items: [UpcomingRecurringItem]) -> [UpcomingRecurringItem] {
        switch self {
        case .descending: return items.sorted { $0.occurrenceDate > $1.occurrenceDate }
        case .ascending: return items.sorted { $0.occurrenceDate < $1.occurrenceDate }
        }
    }
}

/// Which transaction types appear in the home list. Default is all on.
struct TransactionListTypeFilter: OptionSet, Hashable, Sendable {
    let rawValue: Int

    static let expense = Self(rawValue: 1 << 0)
    static let income = Self(rawValue: 1 << 1)
    static let savings = Self(rawValue: 1 << 2)
    static let all: Self = [.expense, .income, .savings]

    /// Menu order: Expense, Income, Savings.
    static let filterOrder: [(Self, TransactionType)] = [
        (.expense, .expense),
        (.income, .income),
        (.savings, .savings)
    ]

    func includes(_ type: TransactionType) -> Bool {
        switch type {
        case .expense: return contains(.expense)
        case .income: return contains(.income)
        case .savings: return contains(.savings)
        }
    }

    mutating func set(_ type: Self, enabled: Bool) {
        if enabled {
            insert(type)
        } else {
            remove(type)
        }
    }
}

/// Persisted home transaction-list options (universal across months).
enum TransactionListPreferences {
    private static var defaults: UserDefaultsHelper { .shared }

    static var groupByCategory: Bool {
        get { defaults.bool(forKey: .groupTransactionsByCategory) }
        set { defaults.set(newValue, forKey: .groupTransactionsByCategory) }
    }

    static var showUpcomingRecurring: Bool {
        get { defaults.bool(forKey: .showUpcomingRecurring) }
        set { defaults.set(newValue, forKey: .showUpcomingRecurring) }
    }

    static var grouping: TransactionListGrouping {
        get { groupByCategory ? .category : .date }
        set { groupByCategory = (newValue == .category) }
    }

    /// Defaults to descending (newest first) when the key has never been written.
    static var sortOrder: TransactionListSortOrder {
        get {
            guard let raw = defaults.string(forKey: .transactionListSortOrder),
                  let order = TransactionListSortOrder(rawValue: raw)
            else {
                return .descending
            }
            return order
        }
        set { defaults.set(newValue.rawValue, forKey: .transactionListSortOrder) }
    }

    /// Defaults to all types visible when the key has never been written.
    static var typeFilter: TransactionListTypeFilter {
        get {
            guard defaults.object(forKey: .transactionListTypeFilter) != nil else {
                return .all
            }
            return TransactionListTypeFilter(
                rawValue: defaults.integer(forKey: .transactionListTypeFilter)
            )
        }
        set { defaults.set(newValue.rawValue, forKey: .transactionListTypeFilter) }
    }
}
