//
//  TransactionListView.swift
//  Xpnse
//
//  Created by Gokul C on 22/10/25.
//

import SwiftUI

struct TransactionListView: View {
    var dateTransactions: [Date: [Transaction]]
    var dates: [Date] = []

    init(dateTransactions: [Date : [Transaction]]) {
        self.dateTransactions = dateTransactions
        for (key, _) in dateTransactions {
            self.dates.append(key)
        }
        self.dates.sort(by: {$0 > $1})
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transactions")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(XpnseColorKey.white.color)

                Spacer(minLength: 0)
            }

            if !self.dates.isEmpty {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(self.dates, id: \.self) { date in
                            self.transactionList(date: date, transactions: dateTransactions[date] ?? [])
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

    private func transactionList(date: Date, transactions: [Transaction]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(date.formattedDate())
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(XpnseColorKey.white.color)

            VStack(spacing: 8) {
                ForEach(transactions) { transaction in
                    TransactionItemView(transaction: transaction)
                }
            }
        }
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
