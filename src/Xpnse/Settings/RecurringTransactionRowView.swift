//
//  RecurringTransactionRowView.swift
//  Xpnse
//

import SwiftUI

struct RecurringTransactionRowView: View {
    let item: RecurringTransaction

    @Environment(\.colorScheme) private var colorScheme
    @State private var categoryStore = CategoryStore.shared

    private var isInactive: Bool {
        item.state == .inactive
    }

    private var transactionType: TransactionType {
        TransactionType(rawValue: item.type) ?? .expense
    }

    private var categoryId: String {
        categoryStore.canonicalCategoryId(
            for: item.categoryIdentifier ?? BuiltinCategories.otherCategoryId
        )
    }

    private var category: CategoryDefinition {
        categoryStore.resolve(id: categoryId)
    }

    private var amountText: String {
        AmountFormatter.format(item.amount, currencyCode: CurrencyManager.shared.selectedCurrency.code)
    }

    private var nextOccurrenceText: String {
        item.nextOccurrence?.formatted(date: .abbreviated, time: .omitted) ?? "—"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transactionType.displayIcon)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(
                    isInactive
                        ? AdaptiveBrandSurface.mutedForeground(for: colorScheme)
                        : transactionType.brandColor
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.system(size: 16, weight: .medium))
                    .xpnseAdaptiveForeground(muted: isInactive)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    CategoryIconBadge(
                        symbolName: category.symbolName,
                        colorHex: category.colorHex,
                        size: 18
                    )
                    .opacity(isInactive ? 0.55 : 1)

                    Text(category.name)
                        .font(.system(size: 12, weight: .light))
                        .xpnseAdaptiveForeground(muted: true)

                    Text("·")
                        .xpnseAdaptiveForeground(muted: true)

                    Text(item.recurrence.displayName)
                        .font(.system(size: 12, weight: .light))
                        .xpnseAdaptiveForeground(muted: true)

                    if let statusBadgeTitle {
                        Text(statusBadgeTitle)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(isInactive ? 0.55 : 0.85))
                            .clipShape(Capsule())
                    }

                    if item.notificationReminderEnabled, !isInactive {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                            .xpnseAdaptiveForeground(muted: true)
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text(amountText)
                    .font(.system(size: 18, weight: .semibold))
                    .xpnseAdaptiveForeground(muted: isInactive)

                Text(scheduleSubtitle)
                    .font(.system(size: 11, weight: .regular))
                    .xpnseAdaptiveForeground(muted: true)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .xpnseOutlinedPanel(
            borderColor: isInactive
                ? AdaptiveBrandSurface.fieldBorder(for: colorScheme).opacity(0.7)
                : nil
        )
        .opacity(rowOpacity)
        .disabled(isInactive)
        .allowsHitTesting(!isInactive)
    }

    private var statusBadgeTitle: String? {
        switch item.state {
        case .paused:
            return L10n.tr("common.paused")
        case .inactive:
            return L10n.tr("common.inactive")
        case .active, .deleted:
            return nil
        }
    }

    private var scheduleSubtitle: String {
        if item.state == .inactive {
            let endedOn = item.endDate ?? item.lastTransactionAddedOn
            let dateText = endedOn?.formatted(date: .abbreviated, time: .omitted) ?? "—"
            return L10n.tr("txn.ended", dateText)
        }
        return "Next \(nextOccurrenceText)"
    }

    private var rowOpacity: Double {
        switch item.state {
        case .inactive:
            return 0.55
        case .paused:
            return 0.72
        case .active, .deleted:
            return 1
        }
    }
}
