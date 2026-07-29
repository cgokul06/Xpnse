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

    private var showsIncomeRatio: Bool {
        income > 0
    }

    var body: some View {
        SummaryCardShell(
            title: L10n.tr("home.current_balance"),
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

    private var currencyCode: String {
        currencyManager.selectedCurrency.code
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
        HStack(alignment: .center, spacing: 8) {
            Text(statEmoji(for: type))
                .font(.system(size: 22))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .xpnseAdaptiveForeground(muted: true)

                Text(AmountFormatter.formatCompact(amount, currencyCode: currencyCode))
                    .font(.system(size: 20, weight: .bold))
                    .xpnseAdaptiveForeground()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func statEmoji(for type: TransactionType) -> String {
        switch type {
        case .expense:
            "💸"
        case .savings:
            "💰"
        case .income:
            type.displayIcon
        }
    }

    @ViewBuilder
    private var balanceAmountView: some View {
        if showsIncomeRatio {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(AmountFormatter.format(totalBalance, currencyCode: currencyCode))
                    .font(.system(size: 28, weight: .bold))
                    .xpnseAdaptiveForeground()

                Text("/")
                    .font(.system(size: 16, weight: .medium))
                    .xpnseAdaptiveForeground(muted: true)

                Text(AmountFormatter.formatCompact(income, currencyCode: currencyCode))
                    .font(.system(size: 16, weight: .semibold))
                    .xpnseAdaptiveForeground(muted: true)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Text(AmountFormatter.format(totalBalance, currencyCode: currencyCode))
                .font(.system(size: 28, weight: .bold))
                .xpnseAdaptiveForeground()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
