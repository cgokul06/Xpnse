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

    var body: some View {
        ZStack {
            PrimaryGradient()

            ScrollView {
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
                        totalBalance: 2345,
                        income: 456,
                        expenses: 123
                    )
                    
                    Spacer()
                    
                    //                AddTransactionButtonContainer(onAddExpense: {}, onAddIncome: {})
                }
                .padding([.horizontal], 16)
                .topSpacingIfNoSafeArea()
            }
            .overlay(alignment: .bottom, content: {
                BottomActionBar {
                    self.homeCoordinator.push(.transactions)
                }
            })
            .navigationBarTitleDisplayMode(.inline)
        }

    }
}

//#Preview {
//    Home()
//}
