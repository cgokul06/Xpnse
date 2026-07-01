//
//  RecurringTransactionRowView.swift
//  Xpnse
//

import SwiftUI

struct RecurringTransactionRowView: View {
    let item: RecurringTransaction

    @State private var categoryStore = CategoryStore.shared

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
        let symbol = CurrencyManager.shared.selectedCurrency.symbol
        return "\(symbol)\(AmountFormatter.format(item.amount))"
    }

    private var nextOccurrenceText: String {
        item.nextOccurrence?.formatted(date: .abbreviated, time: .omitted) ?? "—"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transactionType.displayIcon)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(transactionType.iconFGColor.color)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(XpnseColorKey.white.color)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    CategoryIconBadge(
                        symbolName: category.symbolName,
                        colorHex: category.colorHex,
                        size: 18
                    )
                    Text(category.name)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(XpnseColorKey.white.color.opacity(0.85))

                    Text("·")
                        .foregroundStyle(XpnseColorKey.white.color.opacity(0.5))

                    Text(item.recurrence.displayName)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(XpnseColorKey.white.color.opacity(0.85))

                    if item.state == .paused {
                        Text("Paused")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.85))
                            .clipShape(Capsule())
                    }

                    if item.notificationReminderEnabled {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(XpnseColorKey.white.color.opacity(0.7))
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text(amountText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(XpnseColorKey.white.color)

                Text("Next \(nextOccurrenceText)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(XpnseColorKey.white.color.opacity(0.7))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(XpnseColorKey.transactionListBGColor.color)
        .xpnseRoundedCorner()
        .opacity(item.state == .paused ? 0.72 : 1)
    }
}
