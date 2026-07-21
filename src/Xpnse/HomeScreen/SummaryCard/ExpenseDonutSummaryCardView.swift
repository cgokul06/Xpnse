//
//  ExpenseDonutSummaryCardView.swift
//  Xpnse
//

import Charts
import SwiftUI

struct ExpenseDonutSummaryCardView: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @Environment(\.colorScheme) private var colorScheme

    let summary: TransactionSummary?
    let onFlip: () -> Void

    private var income: Double {
        summary?.totalIncome ?? 0
    }

    private var expenses: Double {
        summary?.totalExpenses ?? 0
    }

    private var savings: Double {
        summary?.totalSavings ?? 0
    }

    private var balance: Double {
        summary?.totalBalance ?? 0
    }

    private var slices: [ExpenseDonutSlice] {
        summary?.financialOverviewSlices() ?? []
    }

    private var legendSlices: [ExpenseDonutSlice] {
        slices.filter { !$0.isRemainder }
    }

    private var chartSlices: [ExpenseDonutSlice] {
        let widgetLegend = legendSlices.map(WidgetDonutSlice.init(expenseSlice:))
        let widgetAll = slices.map(WidgetDonutSlice.init(expenseSlice:))
        return DonutChartSliceBuilder.chartSlices(
            legendSlices: widgetLegend,
            allSlices: widgetAll,
            income: income
        ).map(ExpenseDonutSlice.init(widgetSlice:))
    }

    private var donutCenterTitle: String {
        DonutChartSliceBuilder.centerTitle(income: income)
    }

    private var donutCenterAmount: Double {
        DonutChartSliceBuilder.centerAmount(
            income: income,
            expenses: expenses,
            savings: savings
        )
    }

    private var formattedDonutCenterAmount: String {
        let symbol = currencyManager.selectedCurrency.symbol
        return "\(symbol)\(donutCenterAmount.abbreviatedFloor())"
    }

    private var hasFinancialActivity: Bool {
        income > 0 || expenses > 0 || savings > 0
    }

    var body: some View {
        SummaryCardShell(
            title: "Budget Overview",
            flipIconName: "dollarsign.circle.fill",
            onFlip: onFlip
        ) {
            Group {
                if !hasFinancialActivity {
                    emptyState(message: "No activity yet")
                } else {
                    HStack(alignment: .bottom, spacing: 8) {
                        donutChart
                            .frame(
                                width: SummaryCardMetrics.donutSize,
                                height: SummaryCardMetrics.donutSize
                            )

                        legendView
                            .frame(maxWidth: .infinity)
                            .frame(height: SummaryCardMetrics.donutSize, alignment: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var donutChart: some View {
        ZStack {
            if chartSlices.isEmpty {
                Circle()
                    .stroke(AdaptiveBrandSurface.mutedForeground(for: colorScheme).opacity(0.25), lineWidth: 20)
            } else {
                Chart(chartSlices) { slice in
                    SectorMark(
                        angle: .value("Amount", slice.amount),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .foregroundStyle(sliceColor(for: slice))
                }
                .chartLegend(.hidden)
            }
        }
    }

    @ViewBuilder
    private var legendView: some View {
        if slices.isEmpty {
            emptyState(message: "No activity yet")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(slices) { slice in
                    legendRow(for: slice)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func legendRow(for slice: ExpenseDonutSlice) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(sliceColor(for: slice))
                .frame(width: 10, height: 10)

            Text(slice.name)
                .font(.system(size: 13, weight: .medium))
                .xpnseAdaptiveForeground()
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("\(currencyManager.selectedCurrency.symbol)\(AmountFormatter.format(slice.amount))")
                .font(.system(size: 13, weight: .semibold))
                .xpnseAdaptiveForeground(muted: true)
        }
    }

    private func sliceColor(for slice: ExpenseDonutSlice) -> Color {
        if slice.isRemainder {
            return AdaptiveBrandSurface.mutedForeground(for: colorScheme).opacity(0.25)
        }
        return Color(hex: slice.colorHex)
    }

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .xpnseAdaptiveForeground(muted: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
