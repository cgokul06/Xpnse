//
//  TransactionItemView.swift
//  Xpnse
//
//  Created by Gokul C on 22/10/25.
//

import SwiftUI

struct TransactionItemView: View {
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @State private var isPressed = false
    var transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.type.displayIcon)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(transaction.type.iconFGColor.color)

            VStack(alignment: .leading, spacing: 8) {
                Text(transaction.title)
                    .font(.system(size: 16, weight: .medium))

                Text(transaction.formattedDate)
                    .font(.system(size: 12, weight: .light))
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
        .shadow(color: .black.opacity(isPressed ? 0.3 : 0), radius: isPressed ? 8 : 0, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 50, pressing: { pressing in
            withAnimation {
                isPressed = pressing
            }
        }, perform: {
            // handle tap action here
            self.homeCoordinator.push(.editTransaction(transaction: transaction))
        })
    }
}
