//
//  TransactionCategory.swift
//  Xpnse
//
//  Legacy built-in category ids. Runtime catalog lives in CategoryStore / CategoryDefinition.
//

import Foundation

enum TransactionCategory: String {
    case food = "food"
    case transport = "transport"
    case shopping = "shopping"
    case bills = "bills"
    case health = "health"
    case salary = "salary"
    case business = "business"
    case investments = "investments"
    case rewards = "rewards"
    case gifts = "gifts"
    case other = "other"
}
