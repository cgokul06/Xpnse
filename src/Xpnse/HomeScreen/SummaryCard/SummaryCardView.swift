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
    let savings: Double
    let expenses: Double
    let onFlip: () -> Void

    init(
        totalBalance: Double = 3542.15,
        income: Double = 5240.00,
        savings: Double = 0,
        expenses: Double = 1697.85,
        onFlip: @escaping () -> Void = {}
    ) {
        self.totalBalance = totalBalance
        self.income = income
        self.savings = savings
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

            VStack(alignment: .leading) {
                Text("\(currencyManager.selectedCurrency.symbol) \(totalBalance, specifier: "%.2f")")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                HStack(spacing: 8) {
                    ExpenseComponent(type: .income, cash: income, compact: true)
                        .frame(maxWidth: .infinity)

                    ExpenseComponent(type: .savings, cash: savings, compact: true)
                        .frame(maxWidth: .infinity)

                    ExpenseComponent(type: .expense, cash: expenses, compact: true)
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
