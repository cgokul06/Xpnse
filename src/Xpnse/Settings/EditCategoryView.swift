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
    @State private var emojiInput: String = ""
    @State private var colorHex: String = CategoryColorPalette.defaultHex(for: .expense)
    @State private var canChangeType = true
    @State private var typeChangeMessage: String?
    @State private var isSaving = false
    @State private var nameError: String?
    @State private var emojiError: String?
    @State private var formError: String?

    private var editingCategory: CategoryDefinition? {
        if case .edit(let category) = mode { return category }
        return nil
    }

    private var previewIcon: String {
        CategoryIcon.resolvedIcon(from: emojiInput) ?? CategoryIcon.defaultEmoji
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
                                .xpnseStyledTextField(errorMessage: nameError)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Type")
                                .font(.system(size: 16, weight: .semibold))
                                .xpnseAdaptiveForeground()
                            TransactionTypePicker(
                                selection: $transactionType,
                                isEnabled: canChangeType
                            )

                            if let typeChangeMessage {
                                Text(typeChangeMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .xpnseAdaptiveForeground(muted: true)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Emoji")
                                .font(.system(size: 16, weight: .semibold))
                                .xpnseAdaptiveForeground()
                            TextField("Type an emoji", text: $emojiInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .xpnseStyledTextField(errorMessage: emojiError)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(.system(size: 16, weight: .semibold))
                                .xpnseAdaptiveForeground()
                            CategoryColorPickerView(
                                selectedColorHex: $colorHex,
                                symbolName: previewIcon
                            )
                        }

                        if let formError {
                            Text(formError)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AdaptiveBrandSurface.fieldErrorBorder)
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
                    emojiInput = CategoryIcon.isEmojiIcon(category.symbolName)
                        ? category.symbolName
                        : ""
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
            .onChange(of: name) { _, _ in
                nameError = nil
                formError = nil
            }
            .onChange(of: emojiInput) { _, newValue in
                formError = nil
                updateEmojiError(for: newValue)
            }
            .dismissKeyboardOnOutsideTap(isEnabled: true) {}
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func updateEmojiError(for value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            emojiError = nil
            return
        }
        emojiError = CategoryIcon.normalizedEmojiOrNil(trimmed) == nil
            ? "Enter exactly one emoji."
            : nil
    }

    private func save() async {
        nameError = nil
        emojiError = nil
        formError = nil

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameError = CategoryStoreError.emptyName.localizedDescription
            return
        }

        guard let icon = CategoryIcon.resolvedIcon(from: emojiInput) else {
            emojiError = "Enter exactly one emoji."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            switch mode {
            case .add:
                try await CategoryStore.shared.add(
                    name: trimmed,
                    symbolName: icon,
                    colorHex: colorHex,
                    transactionType: transactionType
                )
            case .edit(let existing):
                var updated = existing
                updated.name = trimmed
                updated.symbolName = icon
                updated.colorHex = CategoryColorPalette.normalizedHex(colorHex)
                if canChangeType {
                    updated.transactionType = transactionType
                }
                try await CategoryStore.shared.update(updated)
            }
            onSaved()
            dismiss()
        } catch {
            formError = error.localizedDescription
        }
    }
}
