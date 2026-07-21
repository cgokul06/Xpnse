//
//  InsightCards.swift
//  Xpnse
//

import SwiftUI

struct InsightHealthCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let score: Int
    let totalScore: Double
    let savingsRate: Double
    let summary: String
    let personalityLabel: String
    let personalityBlurb: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(title: "Financial health", subtitle: nil)

            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { index in
                    Image(systemName: index <= score ? "star.fill" : "star")
                        .foregroundStyle(
                            index <= score
                                ? Color.yellow
                                : AdaptiveBrandSurface.mutedForeground(for: colorScheme).opacity(0.35)
                        )
                        .font(.system(size: 16))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f/5.0", totalScore))
                        .font(.system(size: 13, weight: .semibold))
                        .xpnseAdaptiveForeground()
                    Text("\(Int((savingsRate * 100).rounded()))% forecast savings")
                        .font(.system(size: 12, weight: .medium))
                        .xpnseAdaptiveForeground(muted: true)
                }
            }

            if !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 14, weight: .regular))
                    .xpnseAdaptiveForeground()
            }

            if !personalityLabel.isEmpty || !personalityBlurb.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    if !personalityLabel.isEmpty {
                        Text(personalityLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .xpnseAdaptiveForeground()
                    }
                    if !personalityBlurb.isEmpty {
                        Text(personalityBlurb)
                            .font(.system(size: 13, weight: .regular))
                            .xpnseAdaptiveForeground(muted: true)
                    }
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .xpnseOutlinedPanel()
    }
}

struct InsightBiggestChangesCard: View {
    let changes: [InsightsCategoryDelta]
    let currencySymbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(
                title: "Biggest changes",
                subtitle: "Versus your recent average"
            )

            if changes.isEmpty {
                Text("Not enough history yet for category comparisons.")
                    .font(.system(size: 13))
                    .xpnseAdaptiveForeground(muted: true)
            } else {
                ForEach(changes) { change in
                    HStack(alignment: .firstTextBaseline) {
                        Text(arrow(for: change.direction))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(color(for: change.direction))
                            .frame(width: 20, alignment: .leading)

                        Text(change.name)
                            .font(.system(size: 14, weight: .medium))
                            .xpnseAdaptiveForeground()

                        Spacer()

                        Text(percentText(change))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(color(for: change.direction))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .xpnseOutlinedPanel()
    }

    private func arrow(for direction: InsightsChangeDirection) -> String {
        switch direction {
        case .up: return "↑"
        case .down: return "↓"
        case .stable: return "≈"
        }
    }

    private func color(for direction: InsightsChangeDirection) -> Color {
        switch direction {
        case .up: return Color.red.opacity(0.85)
        case .down: return Color.green.opacity(0.85)
        case .stable: return Color.gray
        }
    }

    private func percentText(_ change: InsightsCategoryDelta) -> String {
        guard let percent = change.percentChange else { return "New" }
        let sign = percent > 0 ? "+" : ""
        return "\(sign)\(Int(percent.rounded()))%"
    }
}

struct InsightTopMerchantsCard: View {
    let merchants: [InsightsMerchantTotal]
    let currencySymbol: String
    let gloss: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(title: "Top spends", subtitle: nil)

            if merchants.isEmpty {
                Text("Add merchant names on transactions to see rankings.")
                    .font(.system(size: 13))
                    .xpnseAdaptiveForeground(muted: true)
            } else {
                ForEach(merchants) { merchant in
                    HStack {
                        Text(merchant.merchant)
                            .font(.system(size: 14, weight: .medium))
                            .xpnseAdaptiveForeground()
                            .lineLimit(1)
                        Spacer()
                        Text("\(currencySymbol)\(AmountFormatter.format(merchant.amount))")
                            .font(.system(size: 14, weight: .semibold))
                            .xpnseAdaptiveForeground()
                    }
                }

                if !gloss.isEmpty {
                    Text(gloss)
                        .font(.system(size: 13, weight: .regular))
                        .xpnseAdaptiveForeground(muted: true)
                        .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .xpnseOutlinedPanel()
    }
}

struct InsightCategoryHealthCard: View {
    let baselines: [InsightsCategoryBaseline]
    let currencySymbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(
                title: "Category health",
                subtitle: "This month vs your usual*"
            )

            if baselines.isEmpty {
                Text("Category baselines appear after a few months of spending.")
                    .font(.system(size: 13))
                    .xpnseAdaptiveForeground(muted: true)
            } else {
                ForEach(baselines) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.name)
                                .font(.system(size: 14, weight: .medium))
                                .xpnseAdaptiveForeground()
                            Spacer()
                            Text(statusLabel(item.status))
                                .font(.system(size: 12, weight: .semibold))
                                .xpnseAdaptiveForeground(muted: true)
                        }

                        // 100% of usual fills the track; over-usual stays full with status color.
                        GeometryReader { geo in
                            let fill = min(1.0, max(0, item.utilization))
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.2))
                                Capsule()
                                    .fill(barColor(item.status))
                                    .frame(width: max(geo.size.width > 0 ? 4 : 0, geo.size.width * fill))
                            }
                        }
                        .frame(height: 8)

                        Text(
                            "\(currencySymbol)\(item.focusAmount.abbreviatedFloor()) this month · usual* \(currencySymbol)\(item.rollingAverage.abbreviatedFloor()) · \(Int((item.utilization * 100).rounded()))%"
                        )
                        .font(.system(size: 12))
                        .xpnseAdaptiveForeground(muted: true)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(alignment: .top, spacing: 2) {
                    Text("*")
                        .font(.system(size: 11, weight: .medium))
                        .xpnseAdaptiveForeground(muted: true)
                    Text(usualLegendBody)
                        .font(.system(size: 11))
                        .xpnseAdaptiveForeground(muted: true)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .xpnseOutlinedPanel()
    }

    private var usualLegendBody: String {
        "Usual is your average monthly spend in that category across up to the three most recent complete months before this one. Months with too little logged data are excluded."
    }

    private func statusLabel(_ status: InsightsCategoryHealthStatus) -> String {
        switch status {
        case .withinRange: return "Near usual"
        case .approaching: return "Above usual"
        case .over: return "Well above usual"
        case .under: return "Below usual"
        }
    }

    private func barColor(_ status: InsightsCategoryHealthStatus) -> Color {
        switch status {
        case .under: return Color.green.opacity(0.75)
        case .withinRange: return Color.yellow.opacity(0.85)
        case .approaching: return Color.orange.opacity(0.85)
        case .over: return Color.red.opacity(0.75)
        }
    }
}

struct InsightForecastCard: View {
    let forecast: InsightsForecast
    let currencySymbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(title: "Predicted month end", subtitle: nil)

            forecastRow(title: "Income", value: forecast.expectedIncome)
            forecastRow(title: "Expected spending", value: forecast.expectedExpense)
            forecastRow(title: "Expected savings", value: forecast.expectedSavings)

            Text("Confidence \(Int((forecast.confidence * 100).rounded()))%")
                .font(.system(size: 13, weight: .medium))
                .xpnseAdaptiveForeground(muted: true)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .xpnseOutlinedPanel()
    }

    private func forecastRow(title: String, value: Double) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .xpnseAdaptiveForeground(muted: true)
            Spacer()
            Text("\(currencySymbol)\(AmountFormatter.format(value))")
                .font(.system(size: 14, weight: .semibold))
                .xpnseAdaptiveForeground()
        }
    }
}

struct InsightOpportunitiesCard: View {
    let opportunities: [String]
    let wins: [String]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(title: "Opportunities & wins", subtitle: nil)

            if isLoading && opportunities.isEmpty && wins.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if opportunities.isEmpty && wins.isEmpty {
                Text("Apple Intelligence can add personalized tips when available.")
                    .font(.system(size: 13))
                    .xpnseAdaptiveForeground(muted: true)
            } else {
                if !opportunities.isEmpty {
                    Text("Potential savings")
                        .font(.system(size: 13, weight: .semibold))
                        .xpnseAdaptiveForeground()
                    ForEach(opportunities, id: \.self) { line in
                        Text("• \(line)")
                            .font(.system(size: 13))
                            .xpnseAdaptiveForeground()
                    }
                }

                if !wins.isEmpty {
                    Text("Wins")
                        .font(.system(size: 13, weight: .semibold))
                        .xpnseAdaptiveForeground()
                        .padding(.top, opportunities.isEmpty ? 0 : 8)
                    ForEach(wins, id: \.self) { line in
                        Text("• \(line)")
                            .font(.system(size: 13))
                            .xpnseAdaptiveForeground(muted: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .xpnseOutlinedPanel()
    }
}

struct InsightEventsCard: View {
    let events: [InsightsFinancialEvent]
    let currencySymbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(
                title: "Detected events",
                subtitle: "Rare / one-time spikes — not recurring or mild overspend"
            )

            ForEach(events.prefix(5)) { event in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(event.title)
                            .font(.system(size: 14, weight: .medium))
                            .xpnseAdaptiveForeground()
                            .lineLimit(1)
                        Spacer()
                        Text("\(currencySymbol)\(AmountFormatter.format(event.amount))")
                            .font(.system(size: 13, weight: .semibold))
                            .xpnseAdaptiveForeground()
                    }
                    Text(event.note)
                        .font(.system(size: 12))
                        .xpnseAdaptiveForeground(muted: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .xpnseOutlinedPanel()
    }
}
