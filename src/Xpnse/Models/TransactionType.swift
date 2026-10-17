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
enum TransactionType: String, CaseIterable, Codable, Hashable {
    case expense = "expense"
    case savings = "savings"
    case income = "income"

    /// UI order: Expense, Savings, Income.
    static var pickerOrder: [TransactionType] {
        [.expense, .savings, .income]
    }

    /// Recurring reminder education is for money leaving the account, not income.
    var isEducationReminderEligible: Bool {
        switch self {
        case .expense, .savings:
            return true
        case .income:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .expense: return L10n.tr("txn.type.expense")
        case .savings: return L10n.tr("txn.type.savings")
        case .income: return L10n.tr("txn.type.income")
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
