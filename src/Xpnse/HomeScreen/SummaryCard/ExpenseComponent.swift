//
//  ExpenseComponent.swift
//  Xpnse
//
//  Created by Gokul C on 21/07/25.
//

import SwiftUI

struct ExpenseComponent: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    let type: TransactionType
    let cash: Double
    var compact: Bool = false

    private var iconSize: CGFloat { compact ? 28 : 40 }
    private var iconFontSize: CGFloat { compact ? 14 : 20 }
    private var titleFontSize: CGFloat { compact ? 11 : 16 }
    private var amountFontSize: CGFloat { compact ? 13 : 20 }

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Image(systemName: type.displayIcon)
                .font(.system(size: iconFontSize, weight: .bold))
                .foregroundColor(.white)
                .frame(width: iconSize, height: iconSize)
                .background(
                    Circle()
                        .fill(type.brandColor)
                )

            VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                Text(type.displayName)
                    .font(.system(size: titleFontSize, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("\(currencyManager.selectedCurrency.symbol)\(cash.abbreviatedFloor())")
                    .font(.system(size: amountFontSize, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
