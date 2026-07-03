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
    let totalSavings: Double
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
        let savingsTransactions = self.allTransactions.filter { $0.type == .savings }
        self.startDate = startDate
        self.endDate = endDate

        self.totalIncome = incomeTransactions.reduce(0) { $0 + $1.totalAmount }
        self.totalExpenses = expenseTransactions.reduce(0) { $0 + $1.totalAmount }
        self.totalSavings = savingsTransactions.reduce(0) { $0 + $1.totalAmount }
        self.totalBalance = totalIncome - totalExpenses - totalSavings
        self.dateRangeText = Self.setupDateSwitcherText(
            currentCalendarComparator: range,
            startDate: startDate,
            endDate: endDate
        ) ?? ""
    }

    // Category-wise breakdown (expenses only; savings excluded per spec)
    func expensesByCategory() -> [String: Double] {
        let expenseTransactions = allTransactions.filter { $0.type == .expense }
        var categoryTotals: [String: Double] = [:]

        for transaction in expenseTransactions {
            categoryTotals[transaction.categoryId, default: 0] += transaction.totalAmount
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
    }
}
