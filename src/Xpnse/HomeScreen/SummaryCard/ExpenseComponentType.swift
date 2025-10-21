//
//  ExpenseComponentType.swift
//  Xpnse
//
//  Created by Gokul C on 21/07/25.
//

import Foundation

enum ExpenseComponentType {
    case income
    case expense

    var title: String {
        switch self {
        case .income:
            return "Income"
        case .expense:
            return "Expense"
        }
    }

    var imageName: String {
        switch self {
        case .income:
            return "arrow.up"
        case .expense:
            return "arrow.down"
        }
    }

    var imageBackgroundColor: XpnseColorKey {
        switch self {
        case .income:
            return XpnseColorKey.incomePrimary
        case .expense:
            return XpnseColorKey.expensePrimary
        }
    }
}
