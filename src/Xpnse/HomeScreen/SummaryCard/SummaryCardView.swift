//
//  SummaryCardView.swift
//  Xpnse
//
//  Created by Gokul C on 21/07/25.
//

import SwiftUI

// MARK: - Financial Summary Card View

struct SummaryCardView: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    let totalBalance: Double
    let income: Double
    let expenses: Double
    let onFlip: () -> Void

    init(
        totalBalance: Double = 3542.15,
        income: Double = 5240.00,
        expenses: Double = 1697.85,
        onFlip: @escaping () -> Void = {}
    ) {
        self.totalBalance = totalBalance
        self.income = income
        self.expenses = expenses
        self.onFlip = onFlip
    }
    
    var body: some View {
        VStack(spacing: SummaryCardMetrics.sectionSpacing) {
            SummaryCardHeaderBar(
                title: "Total Balance",
                flipIconName: "chart.pie.fill",
                onFlip: onFlip
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("\(currencyManager.selectedCurrency.symbol) \(totalBalance, specifier: "%.2f")")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 12) {
                    ExpenseComponent(type: .income, cash: income)
                        .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 48)

                    ExpenseComponent(type: .expense, cash: expenses)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: SummaryCardMetrics.contentAreaHeight, alignment: .topLeading)
        }
        .padding(.horizontal, SummaryCardMetrics.horizontalPadding)
        .padding(.vertical, SummaryCardMetrics.verticalPadding)
        .frame(height: SummaryCardMetrics.height)
        .frame(maxWidth: .infinity)
        .summaryCardFaceBackground()
    }
}

// MARK: - Preview

//struct SummaryCardView_Previews: PreviewProvider {
//    static var previews: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//            
//            VStack(spacing: 30) {
//                Text("Financial Summary Card")
//                    .font(.title)
//                    .fontWeight(.bold)
//                    .foregroundColor(.white)
//                
//                SummaryCardView()
//            }
//            .padding(.horizontal, 16)
//        }
//    }
//}
