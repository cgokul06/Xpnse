//
//  Home.swift
//  Xpnse
//
//  Created by Gokul C on 21/07/25.
//

import SwiftUI

enum SwipeDirection {
    case left, right
}

struct Home: View {
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @StateObject private var homeViewModel: HomeScreenViewModel = HomeScreenViewModel()
//    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack {
            PrimaryGradient()

            contentView
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: self.homeViewModel.currentKey) { _, newKey in
                    Task {
                        await homeViewModel.prefetchIfNeeded(currentKey: newKey)
                    }
                }
        }
    }

    private var contentView: some View {
        VStack(spacing: 16) {
            topView

            dateSwitchView

           cardAndTransactionsList
        }
        .topSpacingIfNoSafeArea()
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
    }

    private var topView: some View {
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
        .padding([.horizontal], 16)
    }

    private var cardAndTransactionsList: some View {
        let txnSummary = self.homeViewModel.transactionSummaryDict[self.homeViewModel.currentKey]
        return VStack(spacing: 16) {
            SummaryCardView(
                totalBalance: txnSummary?.totalBalance ?? 0,
                income: txnSummary?.totalIncome ?? 0,
                expenses: txnSummary?.totalExpenses ?? 0
            )
            .padding([.horizontal], 16)

            TransactionListView(
                transactions: txnSummary?.transactions ?? []
            )
            .padding([.horizontal], 16)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture()
                .onChanged { gesture in
                    print("translation: \(gesture.translation.width)")
//                    offset = gesture.translation.width
                }
                .onEnded { gesture in
                    let horizontalAmount = gesture.translation.width

                    withAnimation(.spring()) {
                        if horizontalAmount < -80 {
                            self.homeViewModel.currentKey += 1
                        } else if horizontalAmount > 80 {
                            self.homeViewModel.currentKey -= 1
                        }
                    }
                }
        )
    }

    private var dateSwitchView: some View {
        let txnSummary = self.homeViewModel.transactionSummaryDict[self.homeViewModel.currentKey]

        return HStack(spacing: 12) {
            Image(systemName: "arrowtriangle.left.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 12)

            Spacer(minLength: 0)

            Text(txnSummary?.dateRangeText ?? "")
                .font(.system(size: 16, weight: .medium))

            Spacer(minLength: 0)

            Image(systemName: "arrowtriangle.right.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(XpnseColorKey.secondaryButtonBGColor.color)
    }
}
