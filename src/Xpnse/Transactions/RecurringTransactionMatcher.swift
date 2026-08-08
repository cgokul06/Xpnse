//
//  RecurringTransactionMatcher.swift
//  Xpnse
//

import Foundation

/// Shared matching for series-linked and untagged spends that belong to a recurring rule.
enum RecurringTransactionMatcher {
    /// Whether `transaction` looks like an occurrence of `rule` (title/merchant + category or amount),
    /// and falls on/after the rule start date (and on/before end date when set).
    static func matches(
        _ transaction: Transaction,
        rule: RecurringTransaction,
        calendar: Calendar = .current
    ) -> Bool {
        guard rule.state == .active || rule.state == .paused else { return false }
        guard rule.type == transaction.type.rawValue else { return false }
        guard isWithinRuleDateWindow(transaction, rule: rule, calendar: calendar) else {
            return false
        }

        let title = normalized(transaction.title)
        let merchant = normalized(transaction.merchant ?? "")
        guard !title.isEmpty || !merchant.isEmpty else { return false }

        let ruleTitle = normalized(rule.title)
        let ruleMerchant = normalized(rule.merchant ?? "")

        let titleMatch = !title.isEmpty && title == ruleTitle
        let merchantMatch = !merchant.isEmpty && !ruleMerchant.isEmpty && merchant == ruleMerchant
        let crossMatch = (!title.isEmpty && title == ruleMerchant)
            || (!merchant.isEmpty && merchant == ruleTitle)

        guard titleMatch || merchantMatch || crossMatch else { return false }

        if let ruleCategory = rule.categoryIdentifier, !ruleCategory.isEmpty {
            if ruleCategory == transaction.categoryId { return true }
        } else {
            return true
        }

        let ruleAmount = Double(truncating: rule.amount as NSNumber)
        return abs(ruleAmount - transaction.totalAmount) < 0.01
    }

    /// Occurrence day must be ≥ rule start and ≤ rule end (when an end date exists).
    static func isWithinRuleDateWindow(
        _ transaction: Transaction,
        rule: RecurringTransaction,
        calendar: Calendar = .current
    ) -> Bool {
        let txDay = calendar.startOfDay(for: Date(timeIntervalSince1970: transaction.date))
        let startDay = calendar.startOfDay(for: rule.startDate)
        guard txDay >= startDay else { return false }
        if let end = rule.endDate {
            let endDay = calendar.startOfDay(for: end)
            guard txDay <= endDay else { return false }
        }
        return true
    }

    static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
