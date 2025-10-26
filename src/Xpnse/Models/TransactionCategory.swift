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
    case transportation = "transportation"
    case shopping = "shopping"
    case entertainment = "entertainment"
    case healthcare = "healthcare"
    case utilities = "utilities"
    case rent = "rent"
    case bills = "bills"
    case education = "education"
    case insurance = "insurance"
    case travel = "travel"
    case dining = "dining"
    case groceries = "groceries"
    case clothing = "clothing"
    case electronics = "electronics"
    case homeMaintenance = "homeMaintenance"
    case personalCare = "personalCare"
    case fitness = "fitness"
    case subscriptions = "subscriptions"
    case taxes = "taxes"
    case debt = "debt"

    // MARK: - Income Categories
    case salary = "salary"
    case freelance = "freelance"
    case business = "business"
    case dividend = "dividend"
    case interest = "interest"
    case rental = "rental"
    case commission = "commission"
    case bonus = "bonus"
    case overtime = "overtime"
    case tips = "tips"
    case gifts = "gifts"
    case lottery = "lottery"
    case gambling = "gambling"
    case insuranceClaim = "insuranceClaim"
    case insuranceMaturity = "insuranceMaturity"
    case sipMaturity = "sipMaturity"
    case fdMaturity = "fdMaturity"
    case mutualFunds = "mutualFunds"
    case stockTrading = "stockTrading"
    case saleOfItem = "saleOfItem"
    case refund = "refund"
    case rebate = "rebate"
    case cashback = "cashback"
    case rewards = "rewards"
    case inheritance = "inheritance"
    case settlement = "settlement"
    case compensation = "compensation"
    case pension = "pension"

    // MARK: - Common
    case other = "other"

    var displayName: String {
        switch self {
        // Expense Categories
        case .food: return "Food & Dining"
        case .transportation: return "Transportation"
        case .shopping: return "Shopping"
        case .entertainment: return "Entertainment"
        case .healthcare: return "Healthcare"
        case .utilities: return "Utilities"
        case .rent: return "Rent"
        case .bills: return "Bills"
        case .education: return "Education"
        case .insurance: return "Insurance"
        case .travel: return "Travel"
        case .dining: return "Dining Out"
        case .groceries: return "Groceries"
        case .clothing: return "Clothing"
        case .electronics: return "Electronics"
        case .homeMaintenance: return "Home Maintenance"
        case .personalCare: return "Personal Care"
        case .fitness: return "Fitness"
        case .subscriptions: return "Subscriptions"
        case .taxes: return "Taxes"
        case .debt: return "Debt Payment"
        case .other: return "Other"
        
        // Income Categories
        case .salary: return "Salary"
        case .freelance: return "Freelance"
        case .business: return "Business"
        case .dividend: return "Dividend"
        case .interest: return "Interest"
        case .rental: return "Rental Income"
        case .commission: return "Commission"
        case .bonus: return "Bonus"
        case .overtime: return "Overtime"
        case .tips: return "Tips"
        case .gifts: return "Gifts"
        case .lottery: return "Lottery"
        case .gambling: return "Gambling"
        case .insuranceClaim: return "Insurance Claim"
        case .insuranceMaturity: return "Insurance Maturity"
        case .sipMaturity: return "SIP Maturity"
        case .fdMaturity: return "FD Maturity"
        case .mutualFunds: return "Mutual Funds"
        case .stockTrading: return "Stock Trading"
        case .saleOfItem: return "Sale of Item"
        case .refund: return "Refund"
        case .rebate: return "Rebate"
        case .cashback: return "Cashback"
        case .rewards: return "Rewards"
        case .inheritance: return "Inheritance"
        case .settlement: return "Settlement"
        case .compensation: return "Compensation"
        case .pension: return "Pension"
        }
    }

    var icon: String {
        switch self {
        // Expense Categories
        case .food: return "fork.knife"
        case .transportation: return "car"
        case .shopping: return "bag"
        case .entertainment: return "tv"
        case .healthcare: return "cross"
        case .utilities: return "bolt"
        case .rent: return "house"
        case .bills: return "calculator"
        case .education: return "book"
        case .insurance: return "shield"
        case .travel: return "airplane"
        case .dining: return "fork.knife.circle"
        case .groceries: return "cart"
        case .clothing: return "tshirt"
        case .electronics: return "laptopcomputer"
        case .homeMaintenance: return "wrench.and.screwdriver"
        case .personalCare: return "person.crop.circle"
        case .fitness: return "figure.run"
        case .subscriptions: return "repeat"
        case .taxes: return "doc.text"
        case .debt: return "creditcard"
        case .other: return "ellipsis.circle"
        
        // Income Categories
        case .salary: return "dollarsign.circle"
        case .freelance: return "briefcase"
        case .business: return "building.2"
        case .dividend: return "chart.pie"
        case .interest: return "percent"
        case .rental: return "house.fill"
        case .commission: return "hand.raised"
        case .bonus: return "star.circle"
        case .overtime: return "clock"
        case .tips: return "hand.thumbsup"
        case .gifts: return "gift"
        case .lottery: return "ticket"
        case .gambling: return "dice"
        case .insuranceClaim: return "shield.checkered"
        case .insuranceMaturity: return "shield.lefthalf.filled"
        case .sipMaturity: return "chart.bar"
        case .fdMaturity: return "banknote"
        case .mutualFunds: return "chart.line.uptrend.xyaxis.circle"
        case .stockTrading: return "chart.xyaxis.line"
        case .saleOfItem: return "tag"
        case .refund: return "arrow.clockwise"
        case .rebate: return "arrow.down.circle"
        case .cashback: return "arrow.up.circle"
        case .rewards: return "star.fill"
        case .inheritance: return "crown"
        case .settlement: return "doc.text.magnifyingglass"
        case .compensation: return "hand.raised.fill"
        case .pension: return "person.2"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Returns all expense categories
    static var expenseCategories: [TransactionCategory] {
        return [
            .food, .transportation, .shopping, .entertainment, .healthcare,
            .utilities, .rent, .bills, .education, .insurance, .travel,
            .dining, .groceries, .clothing, .electronics, .homeMaintenance,
            .personalCare, .fitness, .subscriptions, .taxes, .debt, .other
        ]
    }
    
    /// Returns all income categories
    static var incomeCategories: [TransactionCategory] {
        return [
            .salary, .freelance, .business, .dividend,
            .interest, .rental, .commission, .bonus, .overtime, .tips,
            .gifts, .lottery, .gambling, .insuranceClaim, .insuranceMaturity,
            .sipMaturity, .fdMaturity, .mutualFunds, .stockTrading,
            .saleOfItem, .refund, .rebate, .cashback, .rewards, .inheritance,
            .settlement, .compensation, .pension, .other
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
