//
//  TransactionItemView.swift
//  Xpnse
//
//  Created by Gokul C on 22/10/25.
//

import SwiftUI

struct TransactionItemView: View {
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
    }
}
