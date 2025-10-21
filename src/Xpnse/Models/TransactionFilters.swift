//
//  TransactionFilters.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation

// MARK: - Transaction Filters
struct TransactionFilters {
    var type: TransactionType?
    var category: TransactionCategory?
    var dateRange: ClosedRange<Date>?
    var minAmount: Double?
    var maxAmount: Double?
    var searchText: String?
    var tags: [String]?

    func apply(to transactions: [Transaction]) -> [Transaction] {
        return transactions.filter { transaction in
            // Type filter
            if let type = type, transaction.type != type {
                return false
            }

            // Category filter
            if let category = category, transaction.category != category {
                return false
            }

            // Date range filter
//            if let dateRange = dateRange, !dateRange.contains(transaction.date) {
//                return false
//            }

            // Amount range filter
            if let minAmount = minAmount, transaction.totalAmount < minAmount {
                return false
            }

            if let maxAmount = maxAmount, transaction.totalAmount > maxAmount {
                return false
            }

            // Search text filter
            if let searchText = searchText, !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let matchesTitle = transaction.title.lowercased().contains(searchLower)
                let matchesNotes = transaction.notes?.lowercased().contains(searchLower) ?? false
                let matchesItems = transaction.items.contains { $0.name.lowercased().contains(searchLower) }

                if !matchesTitle && !matchesNotes && !matchesItems {
                    return false
                }
            }

            // Tags filter
            if let tags = tags, !tags.isEmpty {
                let hasMatchingTag = tags.contains { tag in
                    transaction.tags.contains { $0.lowercased() == tag.lowercased() }
                }
                if !hasMatchingTag {
                    return false
                }
            }

            return true
        }
    }
}
