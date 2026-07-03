//
//  TransactionType.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation
import FoundationModels

// MARK: - Transaction Type
@Generable
enum TransactionType: String, CaseIterable, Codable {
    case expense = "expense"
    case savings = "savings"
    case income = "income"

    /// UI order: Expense, Savings, Income.
    static var pickerOrder: [TransactionType] {
        [.expense, .savings, .income]
    }

    var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .savings: return "Savings"
        case .income: return "Income"
        }
    }

    var displayIcon: String {
        switch self {
        case .expense:
            "arrow.down"
        case .savings:
            "banknote"
        case .income:
            "arrow.up"
        }
    }

    var iconFGColor: XpnseColorKey {
        switch self {
        case .expense:
            .expensePrimary
        case .savings:
            .savingsPrimary
        case .income:
            .incomePrimary
        }
    }
}
