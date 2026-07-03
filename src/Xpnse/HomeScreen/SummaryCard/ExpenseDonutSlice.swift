//
//  ExpenseDonutSlice.swift
//  Xpnse
//

import Foundation
import SwiftUI

struct ExpenseDonutSlice: Identifiable, Equatable {
    let id: String
    let name: String
    let amount: Double
    let colorHex: String
    var isRemainder: Bool = false
}

enum FinancialOverviewSliceId {
    static let expense = "overview_expense"
    static let savings = "overview_savings"
    static let balance = "overview_balance"
}

enum FinancialOverviewColors {
    static let balanceHex = "#FFFFFF"
}

extension WidgetDonutSlice {
    init(expenseSlice: ExpenseDonutSlice) {
        self.init(
            id: expenseSlice.id,
            name: expenseSlice.name,
            amount: expenseSlice.amount,
            colorHex: expenseSlice.colorHex,
            isRemainder: expenseSlice.isRemainder
        )
    }
}

extension ExpenseDonutSlice {
    init(widgetSlice: WidgetDonutSlice) {
        self.init(
            id: widgetSlice.id,
            name: widgetSlice.name,
            amount: widgetSlice.amount,
            colorHex: widgetSlice.colorHex,
            isRemainder: widgetSlice.isRemainder
        )
    }
}

extension TransactionSummary {
    func financialOverviewSlices() -> [ExpenseDonutSlice] {
        var slices: [ExpenseDonutSlice] = []

        if totalExpenses > 0 {
            slices.append(
                ExpenseDonutSlice(
                    id: FinancialOverviewSliceId.expense,
                    name: "Expense",
                    amount: totalExpenses,
                    colorHex: TransactionType.expense.brandHex
                )
            )
        }

        if totalSavings > 0 {
            slices.append(
                ExpenseDonutSlice(
                    id: FinancialOverviewSliceId.savings,
                    name: "Savings",
                    amount: totalSavings,
                    colorHex: TransactionType.savings.brandHex
                )
            )
        }

        let balanceAmount = max(0, totalBalance)
        if balanceAmount > 0 {
            slices.append(
                ExpenseDonutSlice(
                    id: FinancialOverviewSliceId.balance,
                    name: "Balance",
                    amount: balanceAmount,
                    colorHex: FinancialOverviewColors.balanceHex,
                    isRemainder: true
                )
            )
        }

        return slices
    }
}
