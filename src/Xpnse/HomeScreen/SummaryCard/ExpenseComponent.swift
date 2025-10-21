//
//  ExpenseComponent.swift
//  Xpnse
//
//  Created by Gokul C on 21/07/25.
//

import SwiftUI

struct ExpenseComponent: View {
    let type: ExpenseComponentType
    let cash: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: type.imageName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(type.imageBackgroundColor.color)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(type.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)

                Text("\(CurrencyManager.shared.selectedCurrency.symbol) \(cash, specifier: "%.2f")")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
