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
    case income = "income"

    var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        }
    }

    var displayIcon: String {
        switch self {
        case .expense:
            "arrow.down"
        case .income:
            "arrow.up"
        }
    }

    var iconFGColor: XpnseColorKey {
        switch self {
        case .expense:
                .expensePrimary
        case .income:
                .incomePrimary
        }
    }
}
