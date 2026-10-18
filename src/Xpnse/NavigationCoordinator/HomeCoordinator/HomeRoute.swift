//
//  HomeRoute.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import Foundation

enum HomeRoute: Route {
//    case main
    case transactions(source: AppAnalytics.TxnSource)
    case addTransaction(prefill: AddTransactionPrefill, source: AppAnalytics.TxnSource)
    case editTransaction(transaction: Transaction)
    case settings
    case manageCategories
//    case profile
    case billScanner
    case insights

    var isNewTransactionForm: Bool {
        if case .transactions = self { return true }
        return false
    }
}

//enum HomeSheet: Route {
//    case addTransaction(type: TransactionType)
//    case transactionDetail(transaction: Transaction)
//}
