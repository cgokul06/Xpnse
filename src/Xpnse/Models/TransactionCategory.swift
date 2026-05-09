//
//  TransactionCategory.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation
import FoundationModels

// MARK: - Transaction Category
@Generable
enum TransactionCategory: String, CaseIterable, Codable {
    // MARK: - Expense Categories
    case food = "food"
    case transport = "transport"
    case shopping = "shopping"
    case bills = "bills"
    case health = "health"

    // MARK: - Income Categories
    case salary = "salary"
    case business = "business"
    case investments = "investments"
    case rewards = "rewards"
    case gifts = "gifts"

    // MARK: - Common
    case other = "other"

    var displayName: String {
        switch self {
        case .food: return "Food"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .bills: return "Bills"
        case .health: return "Health"

        case .salary: return "Salary"
        case .business: return "Business"
        case .investments: return "Investments"
        case .rewards: return "Rewards"
        case .gifts: return "Gifts"

        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        // Expense Categories
        case .food: return "fork.knife"
        case .transport: return "car"
        case .shopping: return "bag"
        case .bills: return "text.pad.header"
        case .health: return "medical.thermometer"
        case .other: return "ellipsis.circle"
        
        // Income Categories
        case .salary: return "dollarsign.circle"
        case .business: return "building.2"
        case .gifts: return "gift"
        case .rewards: return "star.fill"
        case .investments: return "chart.bar"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Returns all expense categories
    static var expenseCategories: [TransactionCategory] {
        return [
            .food, .transport, .shopping, .health, .bills, .other
        ]
    }
    
    /// Returns all income categories
    static var incomeCategories: [TransactionCategory] {
        return [
            .salary, .business, .gifts, .rewards, .investments, .other
        ]
    }
    
    /// Returns categories based on transaction type
    static func categories(for type: TransactionType) -> [TransactionCategory] {
        switch type {
        case .expense:
            return expenseCategories
        case .income:
            return incomeCategories
        }
    }
    
    /// Returns the transaction type for this category
    var transactionType: TransactionType {
        if TransactionCategory.incomeCategories.contains(self) {
            return .income
        } else {
            return .expense
        }
    }
}
