//
//  CoordinatedHomeView.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI

struct CoordinatedHomeView: View {
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @StateObject var billScannerService: BillScannerService = BillScannerService()
//    @EnvironmentObject var appCoordinator: AppCoordinator

    var body: some View {
        NavigationStack(path: $homeCoordinator.path) {
            Home()
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .transactions:
                        AddTransactionView(billScannerService: billScannerService)
                    case .editTransaction(let transaction):
                        AddTransactionView(
                            billScannerService: billScannerService,
                            transaction: transaction
                        )
                    case .settings:
                        Settings()
                    case .billScanner:
                        BillScannerView(billScannerService: billScannerService)
                    }
                }
        }
//        .sheet(item: $homeCoordinator.presentedSheet) { sheet in
//            switch sheet {
//            case .addTransaction(let type):
//                AddTransactionView(type: type)
//            case .transactionDetail(let transaction):
//                TransactionDetailView(transaction: transaction)
//            }
//        }
    }
}

