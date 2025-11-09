//
//  TransactionSummary.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation

// MARK: - Transaction Summary
struct TransactionSummary {
    let totalBalance: Double
    let totalIncome: Double
    let totalExpenses: Double
    let startDate: Date
    let endDate: Date
    let dateRangeText: String
    let transactions: [Date: [Transaction]]
    var allTransactions: [Transaction] = []

    init(transactions: [Date: [Transaction]], startDate: Date, endDate: Date, range: CalendarComparison) {
        self.transactions = transactions

        for (_, value) in transactions {
            allTransactions.append(contentsOf: value)
        }
        let incomeTransactions = self.allTransactions.filter { $0.type == .income }
        let expenseTransactions = self.allTransactions.filter { $0.type == .expense }
        self.startDate = startDate
        self.endDate = endDate

        self.totalIncome = incomeTransactions.reduce(0) { $0 + $1.totalAmount }
        self.totalExpenses = expenseTransactions.reduce(0) { $0 + $1.totalAmount }
        self.totalBalance = totalIncome - totalExpenses
        self.dateRangeText = Self.setupDateSwitcherText(
            currentCalendarComparator: range,
            startDate: startDate,
            endDate: endDate
        ) ?? ""
    }

    // Category-wise breakdown
    func expensesByCategory() -> [TransactionCategory: Double] {
        let expenseTransactions = allTransactions.filter { $0.type == .expense }
        var categoryTotals: [TransactionCategory: Double] = [:]

        for transaction in expenseTransactions {
            categoryTotals[transaction.category, default: 0] += transaction.totalAmount
        }

        return categoryTotals
    }

    private static func setupDateSwitcherText(
        currentCalendarComparator: CalendarComparison,
        startDate: Date,
        endDate: Date
    ) -> String? {
        let formatter = DateFormatter()

        switch currentCalendarComparator {
        case .monthly:
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: startDate)
        case .yearly:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: startDate)
        }
    }

    // Monthly breakdown
    func monthlyBreakdown() -> [String: TransactionSummary] {
        return [:]
//        let calendar = Calendar.current
//        let groupedTransactions = Dictionary(grouping: transactions) { transaction in
//            let components = calendar.dateComponents([.year, .month], from: transaction.date)
//            return "\(components.year!)-\(String(format: "%02d", components.month!))"
//        }
//
//        return groupedTransactions.mapValues { TransactionSummary(transactions: $0) }
    }
}
