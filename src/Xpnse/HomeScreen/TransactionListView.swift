//
//  TransactionListView.swift
//  Xpnse
//
//  Created by Gokul C on 22/10/25.
//

import SwiftUI

struct TransactionListView: View {
    var transactions: [Transaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transactions")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(XpnseColorKey.white.color)

                Spacer(minLength: 0)
            }

            if !transactions.isEmpty {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(transactions) { transaction in
                            TransactionItemView(transaction: transaction)
                        }
                    }
                    .padding(.bottom, 62)
                }
            } else {
                noTransactionsFound
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noTransactionsFound: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                Text("No transactions found!")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(XpnseColorKey.white.color)

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
    }
}
