//
//  TransactionListView.swift
//  Xpnse
//
//  Created by Gokul C on 22/10/25.
//

import SwiftUI

private enum TransactionListGrouping {
    case date
    case category
}

private struct CategorySection: Identifiable {
    let id: String
    let category: CategoryDefinition
    let transactions: [Transaction]
}

struct TransactionListView: View {
    var dateTransactions: [Date: [Transaction]]
    var dates: [Date] = []

    @State private var grouping: TransactionListGrouping = .date
    @State private var categoryStore = CategoryStore.shared

    init(dateTransactions: [Date: [Transaction]]) {
        self.dateTransactions = dateTransactions
        for (key, _) in dateTransactions {
            self.dates.append(key)
        }
        self.dates.sort(by: { $0 > $1 })
    }

    private var allTransactions: [Transaction] {
        dates.flatMap { dateTransactions[$0] ?? [] }
    }

    private var categorySections: [CategorySection] {
        let grouped = Dictionary(grouping: allTransactions) { transaction in
            categoryStore.canonicalCategoryId(for: transaction.categoryId)
        }
        return grouped
            .map { categoryId, transactions in
                CategorySection(
                    id: categoryId,
                    category: categoryStore.resolve(id: categoryId),
                    transactions: transactions.sorted { $0.date > $1.date }
                )
            }
            .sorted { lhs, rhs in
                let lhsSpend = expenseTotal(for: lhs.transactions)
                let rhsSpend = expenseTotal(for: rhs.transactions)
                if lhsSpend != rhsSpend {
                    return lhsSpend > rhsSpend
                }
                let lhsIncome = incomeTotal(for: lhs.transactions)
                let rhsIncome = incomeTotal(for: rhs.transactions)
                if lhsIncome != rhsIncome {
                    return lhsIncome > rhsIncome
                }
                return lhs.category.name.localizedCaseInsensitiveCompare(rhs.category.name) == .orderedAscending
            }
    }

    private func expenseTotal(for transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.totalAmount }
    }

    private func incomeTotal(for transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.totalAmount }
    }

    private func netTotal(for transactions: [Transaction]) -> Double {
        incomeTotal(for: transactions) - expenseTotal(for: transactions)
    }

    @ViewBuilder
    private func sectionNetTotalLabel(for transactions: [Transaction]) -> some View {
        let net = netTotal(for: transactions)
        let currency = transactions.first?.currency ?? CurrencyManager.shared.selectedCurrency
        let isNegative = net < 0
        let displayAmount = abs(net)

        Text("\(currency.symbol)\(String(format: "%.2f", displayAmount))")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isNegative ? Color.red : Color.green)
    }

    private var hasTransactions: Bool {
        switch grouping {
        case .date:
            return !dates.isEmpty
        case .category:
            return !categorySections.isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transactions")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(XpnseColorKey.white.color)

                Spacer(minLength: 0)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        grouping = grouping == .date ? .category : .date
                    }
                } label: {
                    Image(systemName: grouping == .date ? "square.grid.2x2.fill" : "calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(XpnseColorKey.white.color)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel(grouping == .date ? "Group by category" : "Group by date")
            }

            if hasTransactions {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        switch grouping {
                        case .date:
                            ForEach(dates, id: \.self) { date in
                                dateSection(date: date, transactions: dateTransactions[date] ?? [])
                            }
                        case .category:
                            ForEach(categorySections) { section in
                                categorySection(section)
                            }
                        }
                    }
                    .padding(.bottom, 62)
                }
            } else {
                noTransactionsFound
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await categoryStore.load()
        }
    }

    private func dateSection(date: Date, transactions: [Transaction]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(date.formattedDate())
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(XpnseColorKey.white.color)

                Spacer(minLength: 0)

                sectionNetTotalLabel(for: transactions)
            }

            VStack(spacing: 8) {
                ForEach(transactions) { transaction in
                    TransactionItemView(transaction: transaction, subtitle: .category)
                }
            }
        }
    }

    private func categorySection(_ section: CategorySection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                CategoryIconBadge(
                    symbolName: section.category.symbolName,
                    colorHex: section.category.colorHex,
                    size: 24
                )
                Text(section.category.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(XpnseColorKey.white.color)

                Spacer(minLength: 0)

                sectionNetTotalLabel(for: section.transactions)
            }

            VStack(spacing: 8) {
                ForEach(section.transactions) { transaction in
                    TransactionItemView(transaction: transaction, subtitle: .date)
                }
            }
        }
    }

    private var noTransactionsFound: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                Text("No transactions found!")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(XpnseColorKey.white.color)

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
    }
}
