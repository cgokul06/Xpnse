//
//  BalanceWidget.swift
//  XpnseWidgets
//

import AppIntents
import SwiftUI
import WidgetKit

struct BalanceWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetMonthSnapshot
    let shouldHideSensitiveData: Bool
    let isPrivacyEnabled: Bool
    let isRevealActive: Bool
}

struct BalanceWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceWidgetEntry {
        makeEntry(date: Date(), snapshot: previewSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceWidgetEntry) -> Void) {
        completion(makeEntry(date: Date(), snapshot: WidgetDataStore.load() ?? previewSnapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceWidgetEntry>) -> Void) {
        let snapshot = WidgetDataStore.load() ?? .empty
        let entry = makeEntry(date: Date(), snapshot: snapshot)

        let nextUpdate: Date
        if let expiry = WidgetPrivacyManager.revealExpiresAt {
            nextUpdate = expiry
        } else {
            nextUpdate = Calendar.current.date(byAdding: .minute, value: 45, to: Date())
                ?? Date().addingTimeInterval(2700)
        }

        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry(date: Date, snapshot: WidgetMonthSnapshot) -> BalanceWidgetEntry {
        BalanceWidgetEntry(
            date: date,
            snapshot: snapshot,
            shouldHideSensitiveData: WidgetPrivacyManager.shouldHideData,
            isPrivacyEnabled: WidgetPrivacyManager.isEnabled,
            isRevealActive: WidgetPrivacyManager.isRevealActive
        )
    }

    private var previewSnapshot: WidgetMonthSnapshot {
        WidgetMonthSnapshot(
            periodLabel: "May 2026",
            totalBalance: 3542.15,
            totalIncome: 5240,
            totalExpenses: 1697.85,
            totalSavings: 800,
            currencySymbol: "$",
            currencyCode: "USD",
            donutSlices: [],
            expenseCategories: [],
            donutCenterTitle: L10n.tr("common.balance"),
            donutCenterAmount: 3542.15,
            updatedAt: Date()
        )
    }
}

struct BalanceWidgetView: View {
    let entry: BalanceWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private var isSmall: Bool {
        family == .systemSmall
    }

    private var showsIncomeRatio: Bool {
        !isSmall && entry.snapshot.totalIncome > 0
    }

    private var currencyCode: String { entry.snapshot.currencyCode }

    private var hiddenPlaceholder: String { "••••••" }

    @ViewBuilder
    private var balanceHeader: some View {
        if entry.snapshot.periodLabel.isEmpty {
            WidgetSectionHeader(title: L10n.tr("widget.balance.name"), subtitle: nil)
        } else {
            WidgetSectionHeader(
                title: entry.snapshot.periodLabel,
                subtitle: L10n.tr("widget.balance.name")
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                balanceHeader
                    .frame(maxWidth: .infinity, alignment: .leading)

                if entry.isPrivacyEnabled {
                    privacyToggleButton
                }
            }

            Spacer(minLength: isSmall ? 6 : 8)

            balanceAmountView
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(privacyAccessibilityLabel)

            Spacer(minLength: isSmall ? 6 : 10)

            bottomStatsRow
        }
        .padding(0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "\(AppGroupConstants.urlScheme)://home"))
    }

    @ViewBuilder
    private var privacyToggleButton: some View {
        if entry.isRevealActive {
            Button(intent: HideWidgetDataIntent()) {
                privacyButtonLabel(systemImage: "eye.slash")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("widget.hide"))
        } else {
            Button(intent: RevealWidgetDataIntent()) {
                privacyButtonLabel(systemImage: "eye")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("widget.show"))
        }
    }

    private func privacyButtonLabel(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: isSmall ? 12 : 13, weight: .semibold))
            .foregroundStyle(WidgetStyle.mutedText(for: colorScheme))
            .padding(6)
            .background(
                Circle()
                    .fill(WidgetStyle.divider(for: colorScheme).opacity(0.35))
            )
    }

    private var privacyAccessibilityLabel: String {
        if entry.shouldHideSensitiveData {
            return L10n.tr("widget.a11y.hidden")
        }
        if entry.isPrivacyEnabled {
            return L10n.tr("widget.a11y.visible")
        }
        return L10n.tr("widget.balance.name")
    }

    private var bottomStatsRow: some View {
        Group {
            if isSmall {
                VStack(alignment: .leading, spacing: 8) {
                    centeredStat(
                        icon: "banknote",
                        color: WidgetStyle.savings,
                        title: L10n.tr("txn.type.savings"),
                        amount: entry.snapshot.totalSavings,
                        alignment: .leading
                    )

                    centeredStat(
                        icon: "arrow.down",
                        color: WidgetStyle.expense,
                        title: L10n.tr("txn.type.expense"),
                        amount: entry.snapshot.totalExpenses,
                        alignment: .leading
                    )
                }
            } else {
                HStack(spacing: 0) {
                    centeredStat(
                        icon: "banknote",
                        color: WidgetStyle.savings,
                        title: L10n.tr("txn.type.savings"),
                        amount: entry.snapshot.totalSavings,
                        alignment: .center
                    )

                    RoundedRectangle(cornerRadius: 1)
                        .fill(WidgetStyle.divider(for: colorScheme))
                        .frame(width: 2, height: 30)
                        .padding(.horizontal, 12)

                    centeredStat(
                        icon: "arrow.down",
                        color: WidgetStyle.expense,
                        title: L10n.tr("txn.type.expense"),
                        amount: entry.snapshot.totalExpenses,
                        alignment: .center
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(privacyAccessibilityLabel)
    }

    private func displayAmount(_ amount: Double, compact: Bool) -> String {
        if entry.shouldHideSensitiveData {
            return hiddenPlaceholder
        }
        if compact {
            return AmountFormatter.formatCompact(amount, currencyCode: currencyCode)
        }
        return AmountFormatter.format(amount, currencyCode: currencyCode)
    }

    private func formattedBalance(_ balance: Double) -> String {
        displayAmount(balance, compact: isSmall)
    }

    @ViewBuilder
    private var balanceAmountView: some View {
        if showsIncomeRatio && !entry.shouldHideSensitiveData {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedBalance(entry.snapshot.totalBalance))
                    .font(.system(size: isSmall ? 22 : 28, weight: .bold))
                    .foregroundStyle(WidgetStyle.primaryText(for: colorScheme))

                Text("/")
                    .font(.system(size: isSmall ? 14 : 16, weight: .medium))
                    .foregroundStyle(WidgetStyle.mutedText(for: colorScheme))

                Text(displayAmount(entry.snapshot.totalIncome, compact: true))
                    .font(.system(size: isSmall ? 14 : 16, weight: .semibold))
                    .foregroundStyle(WidgetStyle.mutedText(for: colorScheme))
                    .accessibilityExactAmount(entry.snapshot.totalIncome, currencyCode: currencyCode)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Text(formattedBalance(entry.snapshot.totalBalance))
                .font(.system(size: isSmall ? 22 : 28, weight: .bold))
                .foregroundStyle(WidgetStyle.primaryText(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func centeredStat(
        icon: String,
        color: Color,
        title: String,
        amount: Double,
        alignment: HorizontalAlignment
    ) -> some View {
        let iconSize: CGFloat = isSmall ? 16 : 18
        let iconFontSize: CGFloat = isSmall ? 10 : 11
        let titleFontSize: CGFloat = isSmall ? 11 : 13
        let amountFontSize: CGFloat = isSmall ? 16 : 20
        let amountText = displayAmount(amount, compact: true)

        return Group {
            if isSmall {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: iconFontSize, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: iconSize, height: iconSize)
                        .padding(2)
                        .background(Circle().fill(color))

                    Text(amountText)
                        .font(.system(size: amountFontSize, weight: .bold))
                        .foregroundStyle(WidgetStyle.primaryText(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityExactAmount(amount, currencyCode: currencyCode)
                }
            } else {
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: iconFontSize, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: iconSize, height: iconSize)
                            .padding(2)
                            .background(Circle().fill(color))

                        Text(title)
                            .font(.system(size: titleFontSize, weight: .medium))
                            .foregroundStyle(WidgetStyle.mutedText(for: colorScheme))
                    }

                    Text(amountText)
                        .font(.system(size: amountFontSize, weight: .bold))
                        .foregroundStyle(WidgetStyle.primaryText(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityExactAmount(amount, currencyCode: currencyCode)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
}

struct BalanceWidget: Widget {
    let kind = WidgetKinds.balance

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BalanceWidgetProvider()) { entry in
            WidgetStyle.outlinedBackground {
                BalanceWidgetView(entry: entry)
            }
        }
        .configurationDisplayName(LocalizedStringResource("widget.balance.name"))
        .description(LocalizedStringResource("widget.balance.description"))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
