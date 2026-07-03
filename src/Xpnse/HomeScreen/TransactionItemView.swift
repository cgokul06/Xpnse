//
//  TransactionItemView.swift
//  Xpnse
//
//  Created by Gokul C on 22/10/25.
//

import SwiftUI

enum TransactionItemSubtitle {
    case date
    case category
}

struct TransactionItemView: View {
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @State private var isTapped = false
    var transaction: Transaction
    var subtitle: TransactionItemSubtitle = .date

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.type.displayIcon)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(transaction.type.brandColor)

            VStack(alignment: .leading, spacing: 8) {
                Text(transaction.title)
                    .font(.system(size: 16, weight: .medium))

                HStack(spacing: 12) {
                    switch subtitle {
                    case .date:
                        Text(transaction.formattedDate)
                            .font(.system(size: 12, weight: .light))
                    case .category:
                        HStack(spacing: 6) {
                            CategoryIconBadge(
                                symbolName: transaction.categorySymbolName,
                                colorHex: transaction.categoryColorHex,
                                size: 18
                            )
                            Text(transaction.categoryDisplayName)
                                .font(.system(size: 12, weight: .light))
                        }
                    }

                    if transaction.isRecurringGenerated {
                        Text("Recurring")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer(minLength: 0)

            Text(transaction.currency.symbol + " " + transaction.formattedAmount)
                .font(.system(size: 20, weight: .medium))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(XpnseColorKey.transactionListBGColor.color)
        .xpnseRoundedCorner()
        .shadow(
            color: .black.opacity(isTapped ? 0.3 : 0),
            radius: isTapped ? 8 : 0,
            x: 0,
            y: 4
        )
        .scaleEffect(isTapped ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTapped)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isTapped = true
            }
            // simulate tap animation duration before navigation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isTapped = false
                }
                self.homeCoordinator.push(.editTransaction(transaction: transaction))
            }
        }
    }
}
