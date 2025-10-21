//
//  TransactionItem.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation
import FoundationModels

// MARK: - Transaction Item
@Generable
struct TransactionItem: Identifiable, Codable {
    let id = UUID()
    var name: String
    var quantity: Double
    var unitPrice: Double
    var totalPrice: Double?

//    var totalPrice: Double {
//        guard let totalPriceInput else {
//            return quantity * unitPrice
//        }
//        return totalPriceInput
//    }

    init(name: String, quantity: Double, unitPrice: Double, totalPrice: Double? = nil) {
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
    }
}
