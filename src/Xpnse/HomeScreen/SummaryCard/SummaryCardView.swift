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
        totalBalance: Double,
        income: Double,
        savings: Double,
        expenses: Double,
        onFlip: @escaping () -> Void = {}
    ) {
        self.totalBalance = totalBalance
        self.income = income
        self.savings = savings
        self.expenses = expenses
        self.onFlip = onFlip
    }

    private var currencySymbol: String {
        currencyManager.selectedCurrency.symbol
    }

    private var showsIncomeRatio: Bool {
        income > 0
    }

    var body: some View {
        SummaryCardShell(
            title: "Current Balance",
            flipIconName: "chart.pie.fill",
            onFlip: onFlip
        ) {
            VStack(alignment: .leading, spacing: 0) {
                balanceAmountView
                    .frame(
                        height: SummaryCardMetrics.balanceAmountHeight,
                        alignment: .topLeading
                    )

                Color.clear
                    .frame(height: SummaryCardMetrics.balanceToRowSpacing)

                bottomStatsRow
                    .frame(height: SummaryCardMetrics.compactRowHeight, alignment: .center)
            }
        }
    }

    private var bottomStatsRow: some View {
        HStack(spacing: 0) {
            centeredStat(type: .savings, amount: savings)

            RoundedRectangle(cornerRadius: 1)
                .fill(Color.gray.opacity(0.45))
                .frame(width: 2, height: 30)
                .padding(.horizontal, 12)

            centeredStat(type: .expense, amount: expenses)
        }
        .frame(maxWidth: .infinity)
    }

    private func centeredStat(type: TransactionType, amount: Double) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: type.displayIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(type.brandColor))

                Text(type.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }

            Text("\(currencySymbol)\(amount.abbreviatedFloor())")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var balanceAmountView: some View {
        if showsIncomeRatio {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(currencySymbol) \(totalBalance, specifier: "%.2f")")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("/")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)

                Text("\(currencySymbol)\(income.abbreviatedFloor())")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Text("\(currencySymbol) \(totalBalance, specifier: "%.2f")")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
