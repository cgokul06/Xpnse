//
//  CoordinatedHomeView.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI

struct CoordinatedHomeView: View {
    @ObservedObject var transactionManager: FirebaseTransactionManager
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
//    @EnvironmentObject var appCoordinator: AppCoordinator

    var body: some View {
        NavigationStack(path: $homeCoordinator.path) {
            Home(transactionManager: transactionManager)
//            HomeMainView(transactionManager: transactionManager)
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                        //                    case .main:
                        //                        Home(transactionManager: transactionManager)
                    case .transactions:
                        AddTransactionView()
                        //                    case .settings:
                        //                        EmptyView()
                    case .settings:
                        Settings()
                    case .billScanner:
                        BillScannerView()
                        //                    }
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

