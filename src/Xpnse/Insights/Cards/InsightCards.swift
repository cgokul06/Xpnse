//
//  InsightCards.swift
//  Xpnse
//

import SwiftUI

struct InsightHealthCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let totalScore: Double
    let savingsRate: Double
    let summary: String
    let personalityLabel: String
    let personalityBlurb: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(title: L10n.tr("insights.financial_health"), subtitle: nil)

            HStack(spacing: 4) {
                ProportionalStarRating(
                    rating: totalScore,
                    emptyColor: AdaptiveBrandSurface.mutedForeground(for: colorScheme).opacity(0.35)
                )
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f/5.0", totalScore))
                        .font(.system(size: 13, weight: .semibold))
                        .xpnseAdaptiveForeground()
                    Text(L10n.tr("insights.forecast_savings_rate", Int((savingsRate * 100).rounded())))
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

/// Fills stars from a fractional rating (e.g. 3.7 → three full + 70% of the fourth).
private struct ProportionalStarRating: View {
    let rating: Double
    var filledColor: Color = .yellow
    var emptyColor: Color = .gray.opacity(0.35)
    var size: CGFloat = 16

    var body: some View {
        let clamped = min(5, max(0, rating))
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                let fill = min(1, max(0, clamped - Double(index)))
                ZStack {
                    Image(systemName: "star")
                        .foregroundStyle(emptyColor)
                    Image(systemName: "star.fill")
                        .foregroundStyle(filledColor)
                        .mask(alignment: .leading) {
                            GeometryReader { geo in
                                Rectangle()
                                    .frame(width: geo.size.width * fill)
                            }
                        }
                }
                .font(.system(size: size))
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: "%.1f out of 5 stars", clamped)))
    }
}

struct InsightBiggestChangesCard: View {
    let changes: [InsightsCategoryDelta]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(
                title: L10n.tr("insights.biggest_changes"),
                subtitle: L10n.tr("insights.versus_average")
            )

            if changes.isEmpty {
                Text(L10n.tr("insights.not_enough_history"))
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
        guard let percent = change.percentChange else { return L10n.tr("insights.new") }
        let sign = percent > 0 ? "+" : ""
        return "\(sign)\(Int(percent.rounded()))%"
    }
}

struct InsightTopMerchantsCard: View {
    let merchants: [InsightsMerchantTotal]
    let currencyCode: String
    let gloss: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(title: L10n.tr("insights.top_spends"), subtitle: nil)

            if merchants.isEmpty {
                Text(L10n.tr("insights.top_spends_empty"))
                    .font(.system(size: 13))
                    .xpnseAdaptiveForeground(muted: true)
            } else {
                ForEach(merchants) { spend in
                    HStack {
                        Text(spend.merchant)
                            .font(.system(size: 14, weight: .medium))
                            .xpnseAdaptiveForeground()
                            .lineLimit(1)
                        Spacer()
                        Text(AmountFormatter.format(spend.amount, currencyCode: currencyCode))
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
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(
                title: L10n.tr("insights.category_health"),
                subtitle: L10n.tr("insights.vs_usual_subtitle")
            )

            if baselines.isEmpty {
                Text(L10n.tr("insights.baselines_empty"))
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
                            L10n.tr(
                                "insights.category_utilization",
                                AmountFormatter.format(item.focusAmount, currencyCode: currencyCode),
                                AmountFormatter.format(item.rollingAverage, currencyCode: currencyCode),
                                Int((item.utilization * 100).rounded())
                            )
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
                    Text(L10n.tr("insights.usual_legend"))
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

    private func statusLabel(_ status: InsightsCategoryHealthStatus) -> String {
        switch status {
        case .withinRange: return L10n.tr("insights.near_usual")
        case .approaching: return L10n.tr("insights.above_usual")
        case .over: return L10n.tr("insights.well_above_usual")
        case .under: return L10n.tr("insights.below_usual")
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
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(title: L10n.tr("insights.predicted_month_end"), subtitle: nil)

            forecastRow(title: L10n.tr("txn.type.income"), value: forecast.expectedIncome)
            forecastRow(title: L10n.tr("insights.expected_spending"), value: forecast.expectedExpense)
            forecastRow(title: L10n.tr("insights.expected_savings"), value: forecast.expectedSavings)

            Text(L10n.tr("insights.confidence", Int((forecast.confidence * 100).rounded())))
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
            Text(AmountFormatter.format(value, currencyCode: currencyCode))
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
            XpnsePanelHeader(title: L10n.tr("insights.opportunities_wins"), subtitle: nil)

            if isLoading && opportunities.isEmpty && wins.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if opportunities.isEmpty && wins.isEmpty {
                Text(L10n.tr("insights.ai_tips_empty"))
                    .font(.system(size: 13))
                    .xpnseAdaptiveForeground(muted: true)
            } else {
                if !opportunities.isEmpty {
                    Text(L10n.tr("insights.potential_savings"))
                        .font(.system(size: 13, weight: .semibold))
                        .xpnseAdaptiveForeground()
                    ForEach(opportunities, id: \.self) { line in
                        Text("• \(line)")
                            .font(.system(size: 13))
                            .xpnseAdaptiveForeground()
                    }
                }

                if !wins.isEmpty {
                    Text(L10n.tr("insights.wins"))
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
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(
                title: L10n.tr("insights.detected_events"),
                subtitle: L10n.tr("insights.events_subtitle")
            )

            ForEach(events.prefix(5)) { event in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(event.title)
                            .font(.system(size: 14, weight: .medium))
                            .xpnseAdaptiveForeground()
                            .lineLimit(1)
                        Spacer()
                        Text(AmountFormatter.format(event.amount, currencyCode: currencyCode))
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

struct InsightPotentialRecurringCard: View {
    let items: [InsightsPotentialRecurring]
    let currencyCode: String
    let onMakeRecurring: (InsightsPotentialRecurring) -> Void
    let onMarkNotRecurring: (InsightsPotentialRecurring) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XpnsePanelHeader(
                title: L10n.tr("insights.potential_recurring"),
                subtitle: L10n.tr("insights.potential_recurring_subtitle")
            )

            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .medium))
                                .xpnseAdaptiveForeground()
                                .lineLimit(1)
                            if let merchant = item.merchant, !merchant.isEmpty {
                                Text(merchant)
                                    .font(.system(size: 12))
                                    .xpnseAdaptiveForeground(muted: true)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(AmountFormatter.format(item.amount, currencyCode: currencyCode))
                            .font(.system(size: 13, weight: .semibold))
                            .xpnseAdaptiveForeground()
                    }

                    if !item.reason.isEmpty {
                        Text(item.reason)
                            .font(.system(size: 12))
                            .xpnseAdaptiveForeground(muted: true)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(L10n.tr("insights.potential_recurring_confidence", item.confidencePercent))
                        .font(.system(size: 11, weight: .medium))
                        .xpnseAdaptiveForeground(muted: true)

                    HStack(spacing: 10) {
                        Button {
                            onMakeRecurring(item)
                        } label: {
                            Text(L10n.tr("insights.make_recurring"))
                                .font(.system(size: 14, weight: .bold))
                        }
                        .buttonStyle(XpnsePrimaryButtonStyle.defaultButton())

                        Button {
                            onMarkNotRecurring(item)
                        } label: {
                            Text(L10n.tr("insights.not_recurring"))
                                .font(.system(size: 14, weight: .bold))
                        }
                        .buttonStyle(XpnseSecondaryButtonStyle.defaultButton())
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .xpnseOutlinedPanel()
        .animation(.easeInOut(duration: 0.2), value: items.map(\.id))
    }
}
