//
//  Home.swift
//  Xpnse
//
//  Created by Gokul C on 21/07/25.
//

import SwiftUI

struct Home: View {
    @ObservedObject var transactionManager: FirebaseTransactionManager
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @StateObject private var homeViewModel: HomeScreenViewModel = HomeScreenViewModel()

    var body: some View {
        ZStack {
            PrimaryGradient()

//            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Xpnse")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(XpnseColorKey.white.color)
                            
                            Text("Track your expenses")
                                .foregroundColor(XpnseColorKey.white.color)
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            //                        Button {
                            //
                            //                        } label: {
                            //                            Image(systemName: "bell.fill")
                            //                                .resizable()
                            //                                .renderingMode(.template)
                            //                                .frame(width: 18, height: 18)
                            //                                .foregroundStyle(XpnseColorKey.white.color)
                            //                        }
                            
                            Button {
                                homeCoordinator.push(.settings)
                            } label: {
                                Image(systemName: "gear")
                                    .resizable()
                                    .renderingMode(.template)
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(XpnseColorKey.white.color)
                            }
                            
                        }
                    }

                    SummaryCardView(
                        totalBalance: self.transactionManager.transactionSummary?.totalBalance ?? 0,
                        income: self.transactionManager.transactionSummary?.totalIncome ?? 0,
                        expenses: self.transactionManager.transactionSummary?.totalExpenses ?? 0
                    )

                    TransactionListView(
                        transactions: self.transactionManager.transactionSummary?.transactions ?? []
                    )

                    Spacer(minLength: 0)
                }
                .padding([.horizontal], 16)
                .topSpacingIfNoSafeArea()
//            }
            .overlay(
                alignment: .bottom,
                content: {
                    Button {
                        self.homeCoordinator.push(.transactions)
                    } label: {
                        Text("Add transaction")
                            .font(.system(size: 20, weight: .bold))
                    }
                    .buttonStyle(
                        XpnsePrimaryButtonStyle.defaultButton(
                            bgColor: XpnseColorKey.secondaryButtonBGColor,
                            isDisabled: .constant(false),
                            isLoading: .constant(false)
                        )
                    )
                    .padding(.horizontal, 16)
                    .bottomSpacingIfNoSafeArea(8)
            })
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: self.homeViewModel.id) {
            guard let startDate = homeViewModel.startDate,
                  let endDate = homeViewModel.endDate else {
                return
            }

            await self.transactionManager.loadTransactions(
                startDate: startDate,
                endDate: endDate
            )
        }
        .onChange(of: self.transactionManager.reloadTransactions) { _, reloadTransactions in
            guard reloadTransactions else { return }

            guard let startDate = homeViewModel.startDate,
                  let endDate = homeViewModel.endDate else {
                self.transactionManager.resetReloadTransaction()
                return
            }

            Task {
                await self.transactionManager.loadTransactions(
                    startDate: startDate,
                    endDate: endDate
                )
            }
        }
    }
}

//#Preview {
//    Home()
//}

