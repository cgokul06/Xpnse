//
//  ExpenseDonutSlice.swift
//  Xpnse
//

import Foundation

struct ExpenseDonutSlice: Identifiable, Equatable {
    let id: String
    let name: String
    let amount: Double
    let colorHex: String
    var isRemainder: Bool = false
}

extension TransactionSummary {
    @MainActor
    func expenseDonutSlices(categoryStore: CategoryStore = .shared) -> [ExpenseDonutSlice] {
        var categoryTotals: [String: Double] = [:]
        for transaction in allTransactions where transaction.type == .expense {
            let canonicalId = categoryStore.canonicalCategoryId(for: transaction.categoryId)
            categoryTotals[canonicalId, default: 0] += transaction.totalAmount
        }

        var slices = categoryTotals.map { categoryId, amount in
            let category = categoryStore.resolve(id: categoryId)
            return ExpenseDonutSlice(
                id: categoryId,
                name: category.name,
                amount: amount,
                colorHex: category.colorHex
            )
        }
        .sorted { $0.amount > $1.amount }

        if totalIncome > 0 {
            let remainder = max(0, totalIncome - totalExpenses)
            if remainder > 0 {
                slices.append(
                    ExpenseDonutSlice(
                        id: "__remainder__",
                        name: "Remaining",
                        amount: remainder,
                        colorHex: "FFFFFF",
                        isRemainder: true
                    )
                )
            }
        }

        return slices
    }
}
