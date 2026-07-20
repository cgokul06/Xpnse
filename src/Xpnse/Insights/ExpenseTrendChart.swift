//
//  ExpenseTrendChart.swift
//  Xpnse
//

import Charts
import SwiftUI

struct ExpenseTrendChart: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @Environment(\.colorScheme) private var colorScheme

    let model: ExpenseTrendChartModel

    private static let visibleDayCount: Double = 12
    private static let lineWidth: CGFloat = 3.5
    private static let chartHeight: CGFloat = 260
    private static let borderWidth: CGFloat = 2.5

    private var currencySymbol: String {
        currencyManager.selectedCurrency.symbol
    }

    private var borderColor: Color {
        AdaptiveBrandSurface.fieldBorder(for: colorScheme)
    }

    private var gridColor: Color {
        AdaptiveBrandSurface.mutedForeground(for: colorScheme).opacity(0.35)
    }

    private var projectedMonthColor: Color {
        guard let month = model.projectedMonth else {
            return ExpenseTrendMonthPalette.colors[0]
        }
        return ExpenseTrendMonthPalette.color(forMonth: month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Expense trend")
                    .font(.system(size: 18, weight: .semibold))
                    .xpnseAdaptiveForeground()

                Text("Cumulative by day · \(model.year)")
                    .font(.system(size: 13, weight: .medium))
                    .xpnseAdaptiveForeground(muted: true)
            }

            chart
                .frame(height: Self.chartHeight)
                .padding(.vertical, 8)
                .padding(.trailing, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: Self.borderWidth)
                )

            legend
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chart: some View {
        Chart {
            ForEach(model.actualPoints) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Amount", point.cumulativeAmount),
                    series: .value("Series", "actual-\(point.month)")
                )
                .foregroundStyle(ExpenseTrendMonthPalette.color(forMonth: point.month))
                .interpolationMethod(.linear)
                .lineStyle(
                    StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round)
                )
            }

            ForEach(model.projectedPoints) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Amount", point.cumulativeAmount),
                    series: .value("Series", "projected-\(point.month)")
                )
                .foregroundStyle(ExpenseTrendMonthPalette.color(forMonth: point.month))
                .interpolationMethod(.linear)
                .lineStyle(
                    StrokeStyle(
                        lineWidth: Self.lineWidth,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [7, 5]
                    )
                )
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: Self.visibleDayCount)
        .chartXScale(domain: 1...31)
        .chartXAxis {
            AxisMarks(values: Array(1...31)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(gridColor)
                AxisTick(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(gridColor)
                AxisValueLabel {
                    if let day = value.as(Int.self) {
                        Text("\(day)")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(gridColor)
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text("\(currencySymbol)\(amount.abbreviatedFloor())")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.background(.clear)
        }
    }

    private var legend: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 72), alignment: .leading)
            ],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(model.monthsInChart, id: \.self) { month in
                HStack(spacing: 6) {
                    Capsule()
                        .fill(ExpenseTrendMonthPalette.color(forMonth: month))
                        .frame(width: 14, height: 3)

                    Text(ExpenseTrendMonthPalette.shortLabel(forMonth: month))
                        .font(.system(size: 12, weight: .medium))
                        .xpnseAdaptiveForeground(muted: true)
                }
            }

            if model.hasProjection {
                HStack(spacing: 6) {
                    ProjectedLegendDash(color: projectedMonthColor)

                    Text("Projected")
                        .font(.system(size: 12, weight: .medium))
                        .xpnseAdaptiveForeground(muted: true)
                }
            }
        }
    }
}

private struct ProjectedLegendDash: View {
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Capsule().fill(color).frame(width: 5, height: 3)
            Capsule().fill(color).frame(width: 5, height: 3)
            Capsule().fill(color).frame(width: 5, height: 3)
        }
        .frame(width: 18, alignment: .leading)
    }
}
