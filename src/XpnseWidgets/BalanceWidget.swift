//
//  BalanceWidget.swift
//  XpnseWidgets
//

import SwiftUI
import WidgetKit

struct BalanceWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetMonthSnapshot
}

struct BalanceWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceWidgetEntry {
        BalanceWidgetEntry(date: Date(), snapshot: previewSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceWidgetEntry) -> Void) {
        completion(BalanceWidgetEntry(date: Date(), snapshot: WidgetDataStore.load() ?? previewSnapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceWidgetEntry>) -> Void) {
        let snapshot = WidgetDataStore.load() ?? .empty
        let entry = BalanceWidgetEntry(date: Date(), snapshot: snapshot)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 45, to: Date()) ?? Date().addingTimeInterval(2700)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private var previewSnapshot: WidgetMonthSnapshot {
        WidgetMonthSnapshot(
            periodLabel: "May 2026",
            totalBalance: 3542.15,
            totalIncome: 5240,
            totalExpenses: 1697.85,
            currencySymbol: "$",
            donutSlices: [],
            expenseCategories: [],
            donutCenterTitle: "Income",
            donutCenterAmount: 5240,
            updatedAt: Date()
        )
    }
}

struct BalanceWidgetView: View {
    let entry: BalanceWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var isSmall: Bool {
        family == .systemSmall
    }

    @ViewBuilder
    private var balanceHeader: some View {
        if entry.snapshot.periodLabel.isEmpty {
            WidgetSectionHeader(title: "Total Balance", subtitle: nil)
        } else {
            WidgetSectionHeader(
                title: entry.snapshot.periodLabel,
                subtitle: "Total Balance"
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 8 : 12) {
            balanceHeader

            Text("\(entry.snapshot.currencySymbol)\(AmountFormatter.format(entry.snapshot.totalBalance))")
                .font(.system(size: isSmall ? 24 : 30, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.65)
                .lineLimit(1)

            Spacer(minLength: 0)

            if isSmall {
                VStack(alignment: .leading, spacing: 6) {
                    metric(
                        icon: "arrow.up",
                        color: WidgetStyle.income,
                        title: "Income",
                        amount: entry.snapshot.totalIncome,
                        compact: true
                    )

                    Rectangle()
                        .fill(WidgetStyle.divider)
                        .frame(height: 1)

                    metric(
                        icon: "arrow.down",
                        color: WidgetStyle.expense,
                        title: "Expense",
                        amount: entry.snapshot.totalExpenses,
                        compact: true
                    )
                }
            } else {
                HStack(spacing: 10) {
                    metric(
                        icon: "arrow.up",
                        color: WidgetStyle.income,
                        title: "Income",
                        amount: entry.snapshot.totalIncome,
                        compact: false
                    )
                    Rectangle()
                        .fill(WidgetStyle.divider)
                        .frame(width: 1, height: 34)
                    metric(
                        icon: "arrow.down",
                        color: WidgetStyle.expense,
                        title: "Expense",
                        amount: entry.snapshot.totalExpenses,
                        compact: false
                    )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "\(AppGroupConstants.urlScheme)://home"))
    }

    private func metric(icon: String, color: Color, title: String, amount: Double, compact: Bool) -> some View {
        HStack(spacing: compact ? 5 : 8) {
            Image(systemName: icon)
                .font(.system(size: compact ? 12 : 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: compact ? 20 : 26, height: compact ? 20 : 26)
                .background(Circle().fill(color))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: compact ? 11 : 12, weight: .medium))
                    .foregroundStyle(WidgetStyle.mutedText)
                Text("\(entry.snapshot.currencySymbol)\(WidgetAbbreviation.format(amount))")
                    .font(.system(size: compact ? 13 : 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BalanceWidget: Widget {
    let kind = WidgetKinds.balance

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BalanceWidgetProvider()) { entry in
            WidgetStyle.cardBackground {
                BalanceWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Total Balance")
        .description("Current period balance, income, and expenses.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
