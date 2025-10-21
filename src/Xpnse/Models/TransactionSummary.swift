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
    let transactions: [Transaction]

    init(transactions: [Transaction]) {
        self.transactions = transactions

        let incomeTransactions = transactions.filter { $0.type == .income }
        let expenseTransactions = transactions.filter { $0.type == .expense }

        self.totalIncome = incomeTransactions.reduce(0) { $0 + $1.totalAmount }
        self.totalExpenses = expenseTransactions.reduce(0) { $0 + $1.totalAmount }
        self.totalBalance = totalIncome - totalExpenses
    }

    // Category-wise breakdown
    func expensesByCategory() -> [TransactionCategory: Double] {
        let expenseTransactions = transactions.filter { $0.type == .expense }
        var categoryTotals: [TransactionCategory: Double] = [:]

        for transaction in expenseTransactions {
            categoryTotals[transaction.category, default: 0] += transaction.totalAmount
        }

        return categoryTotals
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
