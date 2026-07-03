//
//  EditCategoryView.swift
//  Xpnse
//

import SwiftUI

struct EditCategoryView: View {
    enum Mode {
        case add
        case edit(CategoryDefinition)
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let onSaved: () -> Void

    @State private var name: String = ""
    @State private var transactionType: TransactionType = .expense
    @State private var symbolName: String = "tag.fill"
    @State private var colorHex: String = CategoryColorPalette.defaultHex(for: .expense)
    @State private var canChangeType = true
    @State private var typeChangeMessage: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var editingCategory: CategoryDefinition? {
        if case .edit(let category) = mode { return category }
        return nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PrimaryGradient()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.system(size: 16, weight: .semibold))
                                .xpnseAdaptiveForeground()
                            TextField("Category name", text: $name)
                                .textFieldStyle(XpnseTextFieldStyle())
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.system(size: 16, weight: .semibold))
                                .xpnseAdaptiveForeground()
                            Picker("Type", selection: $transactionType) {
                                Text("Expense").tag(TransactionType.expense)
                                Text("Savings").tag(TransactionType.savings)
                                Text("Income").tag(TransactionType.income)
                            }
                            .pickerStyle(.segmented)
                            .disabled(!canChangeType)

                            if let typeChangeMessage {
                                Text(typeChangeMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .xpnseAdaptiveForeground(muted: true)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon")
                                .font(.system(size: 16, weight: .semibold))
                                .xpnseAdaptiveForeground()
                            SFSymbolPickerView(selectedSymbol: $symbolName)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(.system(size: 16, weight: .semibold))
                                .xpnseAdaptiveForeground()
                            CategoryColorPickerView(
                                selectedColorHex: $colorHex,
                                symbolName: symbolName
                            )
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .xpnseAdaptiveForeground()
                }
                ToolbarItem(placement: .principal) {
                    Text(editingCategory == nil ? "New Category" : "Edit Category")
                        .font(.title3)
                        .fontWeight(.bold)
                        .xpnseAdaptiveForeground()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                    .xpnseAdaptiveForeground()
                }
            }
            .task {
                if let category = editingCategory {
                    name = category.name
                    transactionType = category.transactionType
                    symbolName = category.symbolName
                    colorHex = category.colorHex
                    let restriction = CategoryStore.shared.typeChangeRestriction(for: category.id)
                    canChangeType = !restriction.blocksTypeChange
                    typeChangeMessage = restriction.editMessage
                }
            }
            .onChange(of: transactionType) { _, newType in
                if editingCategory == nil,
                   !CategoryColorPalette.isValid(colorHex) {
                    colorHex = CategoryColorPalette.defaultHex(for: newType)
                }
            }
        }
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = CategoryStoreError.emptyName.localizedDescription
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            switch mode {
            case .add:
                try await CategoryStore.shared.add(
                    name: trimmed,
                    symbolName: symbolName,
                    colorHex: colorHex,
                    transactionType: transactionType
                )
            case .edit(let existing):
                var updated = existing
                updated.name = trimmed
                updated.symbolName = symbolName
                updated.colorHex = CategoryColorPalette.normalizedHex(colorHex)
                if canChangeType {
                    updated.transactionType = transactionType
                }
                try await CategoryStore.shared.update(updated)
            }
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
