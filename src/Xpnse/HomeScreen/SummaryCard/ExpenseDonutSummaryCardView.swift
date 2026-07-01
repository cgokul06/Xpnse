//
//  ExpenseDonutSummaryCardView.swift
//  Xpnse
//

import Charts
import SwiftUI

struct ExpenseDonutSummaryCardView: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var categoryStore = CategoryStore.shared

    let summary: TransactionSummary?
    let onFlip: () -> Void

    private var income: Double {
        summary?.totalIncome ?? 0
    }

    private var expenses: Double {
        summary?.totalExpenses ?? 0
    }

    private var slices: [ExpenseDonutSlice] {
        summary?.expenseDonutSlices(categoryStore: categoryStore) ?? []
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
        DonutChartSliceBuilder.centerAmount(income: income, expenses: expenses)
    }

    private var formattedDonutCenterAmount: String {
        let symbol = currencyManager.selectedCurrency.symbol
        return "\(symbol)\(donutCenterAmount.abbreviatedFloor())"
    }

    var body: some View {
        VStack(spacing: SummaryCardMetrics.sectionSpacing) {
            SummaryCardHeaderBar(
                title: "Expense Breakdown",
                flipIconName: "dollarsign.circle.fill",
                onFlip: onFlip
            )

            Group {
                if expenses <= 0, income <= 0 {
                    emptyState(message: "No expenses yet")
                } else {
                    HStack(alignment: .center, spacing: 12) {
                        donutChart
                            .frame(
                                width: SummaryCardMetrics.donutSize,
                                height: SummaryCardMetrics.donutSize
                            )

                        legendView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(height: SummaryCardMetrics.contentAreaHeight)
        }
        .padding(.horizontal, SummaryCardMetrics.horizontalPadding)
        .padding(.vertical, SummaryCardMetrics.verticalPadding)
        .frame(height: SummaryCardMetrics.height)
        .frame(maxWidth: .infinity)
        .summaryCardFaceBackground()
        .task {
            await categoryStore.load()
        }
    }

    @ViewBuilder
    private var donutChart: some View {
        ZStack {
            if chartSlices.isEmpty {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 20)
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

            VStack(spacing: 2) {
                Text(donutCenterTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)

                Text(formattedDonutCenterAmount)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if expenses == 0, income > 0 {
                    Text("No expenses yet")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 6)
        }
    }

    @ViewBuilder
    private var legendView: some View {
        if legendSlices.isEmpty && expenses == 0 {
            Text("No expenses yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if legendSlices.isEmpty {
            emptyState(message: "No expenses yet")
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(legendSlices) { slice in
                        legendRow(for: slice)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func legendRow(for slice: ExpenseDonutSlice) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: slice.colorHex))
                .frame(width: 10, height: 10)

            Text(slice.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("\(currencyManager.selectedCurrency.symbol)\(AmountFormatter.format(slice.amount))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    private func sliceColor(for slice: ExpenseDonutSlice) -> Color {
        if slice.isRemainder {
            return Color.white.opacity(0.2)
        }
        return Color(hex: slice.colorHex)
    }

    private func emptyState(message: String) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
