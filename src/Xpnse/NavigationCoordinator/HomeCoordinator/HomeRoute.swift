//
//  HomeRoute.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import Foundation

enum HomeRoute: Route {
//    case main
    case transactions
    case addTransaction(prefill: AddTransactionPrefill)
    case editTransaction(transaction: Transaction)
    case settings
    case manageCategories
//    case profile
    case billScanner
    case insights
}

//enum HomeSheet: Route {
//    case addTransaction(type: TransactionType)
//    case transactionDetail(transaction: Transaction)
//}
