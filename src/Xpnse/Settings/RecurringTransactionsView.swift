//
//  RecurringTransactionsView.swift
//  Xpnse
//
//  Created by Gokul C on 05/05/26.
//

import SwiftUI

struct RecurringTransactionsView: View {
    @State private var recurringItems: [RecurringTransaction] = []
    @State private var isLoading = true
    @State private var selectedForEdit: RecurringTransaction?

    private let transactionManager = FirebaseTransactionManager.shared

    var body: some View {
        List {
            if recurringItems.isEmpty && !isLoading {
                Text("No recurring transactions found.")
                    .foregroundStyle(.secondary)
            }

            ForEach(recurringItems, id: \.id) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                    Text("Next: \(item.nextOccurrence?.formatted(date: .abbreviated, time: .omitted) ?? "—")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Amount: \(CurrencyManager.shared.selectedCurrency.symbol)\(NSDecimalNumber(decimal: item.amount).stringValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Skip") {
                        Task {
                            await transactionManager.skipRecurringTransaction(id: item.id)
                            await reload()
                        }
                    }
                    .tint(.orange)

                    Button("Cancel", role: .destructive) {
                        Task {
                            await transactionManager.cancelRecurringTransaction(id: item.id)
                            await reload()
                        }
                    }
                }
                .onTapGesture {
                    selectedForEdit = item
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Recurring Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedForEdit) { item in
            EditRecurringTransactionView(item: item) {
                Task { await reload() }
            }
        }
        .task {
            await reload()
        }
    }

    private func reload() async {
        isLoading = true
        recurringItems = await transactionManager.fetchRecurringTransactions()
            .sorted { ($0.nextOccurrence ?? .distantFuture) < ($1.nextOccurrence ?? .distantFuture) }
        isLoading = false
    }
}

private struct EditRecurringTransactionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var amount: String
    @State private var categoryIdentifier: String
    @State private var recurrence: RecurrenceFrequency

    private let original: RecurringTransaction
    private let onSaved: () -> Void
    private let transactionManager = FirebaseTransactionManager.shared

    init(item: RecurringTransaction, onSaved: @escaping () -> Void) {
        self.original = item
        self._title = State(initialValue: item.title)
        self._amount = State(initialValue: NSDecimalNumber(decimal: item.amount).stringValue)
        self._categoryIdentifier = State(initialValue: item.categoryIdentifier ?? TransactionCategory.other.rawValue)
        self._recurrence = State(initialValue: item.recurrence)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                TextField("Category", text: $categoryIdentifier)
                Text(recurrence.displayName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Update Recurring")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let updated = RecurringTransaction(
                                id: original.id,
                                title: title,
                                type: original.type,
                                categoryIdentifier: categoryIdentifier,
                                amount: Decimal(string: amount) ?? original.amount,
                                startDate: original.startDate,
                                endDate: original.endDate,
                                recurrence: recurrence,
                                nextOccurrence: original.nextOccurrence,
                                metadata: original.metadata
                            )
                            await transactionManager.updateRecurringTransaction(updated)
                            onSaved()
                            dismiss()
                        }
                    }
                }
            }
        }
    }

}
