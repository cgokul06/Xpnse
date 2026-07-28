//
//  ExtractedDataPreview.swift
//  Xpnse
//
//  Created by Gokul C on 16/09/25.
//

import SwiftUI

struct ExtractedDataPreview: View {
    let data: Transaction

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("scanner.preview")
                .font(.headline)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                ScrollView {
                    DataRow(
                        label: L10n.tr("common.amount"),
                        value: AmountFormatter.format(
                            data.amount,
                            currencyCode: CurrencyManager.shared.selectedCurrency.code
                        )
                    )

                    DataRow(label: L10n.tr("common.merchant"), value: data.title)

                    DataRow(label: L10n.tr("common.date"), value: data.formattedDate)

                    DataRow(label: L10n.tr("common.category"), value: data.categoryDisplayName)

                    ForEach(data.items, id: \.id) { item in
                        DataRow(
                            label: item.name,
                            value: "qty: \(item.quantity) price: \(item.unitPrice) total: \(item.totalPrice ?? 0.0)"
                        )
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .xpnseRoundedCorner()
            }
        }
        .padding(.horizontal)
    }
}

fileprivate struct DataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}
