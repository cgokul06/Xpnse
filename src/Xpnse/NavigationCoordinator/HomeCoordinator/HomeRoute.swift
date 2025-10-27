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
    case editTransaction(transaction: Transaction)
    case settings
//    case profile
    case billScanner
}

//enum HomeSheet: Route {
//    case addTransaction(type: TransactionType)
//    case transactionDetail(transaction: Transaction)
//}
