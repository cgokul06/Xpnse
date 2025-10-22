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
            Text("Transactions")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(XpnseColorKey.white.color)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(transactions) { transaction in
                        TransactionItemView(transaction: transaction)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}
