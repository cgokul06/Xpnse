//
//  ManageCategoriesView.swift
//  Xpnse
//

import SwiftUI

struct ManageCategoriesView: View {
    @State private var categoryStore = CategoryStore.shared
    @State private var editingCategory: CategoryDefinition?
    @State private var showAddCategory = false
    @State private var deleteError: String?
    @State private var showDeleteError = false

    private var expenseCategories: [CategoryDefinition] {
        categoryStore.categories(for: .expense)
    }

    private var incomeCategories: [CategoryDefinition] {
        categoryStore.categories(for: .income)
    }

    var body: some View {
        List {
            Section("Expense") {
                ForEach(expenseCategories) { category in
                    categoryRow(category)
                }
            }

            Section("Income") {
                ForEach(incomeCategories) { category in
                    categoryRow(category)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .gradientNavigationBackground()
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                }
            }
        }
        .task {
            await categoryStore.load()
        }
        .sheet(isPresented: $showAddCategory) {
            EditCategoryView(mode: .add) {
                Task { await categoryStore.load() }
            }
        }
        .sheet(item: $editingCategory) { category in
            EditCategoryView(mode: .edit(category)) {
                Task { await categoryStore.load() }
            }
        }
        .alert("Could Not Delete", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    @ViewBuilder
    private func categoryRow(_ category: CategoryDefinition) -> some View {
        Button {
            editingCategory = category
        } label: {
            HStack(spacing: 12) {
                CategoryIconBadge(
                    symbolName: category.symbolName,
                    colorHex: category.colorHex,
                    size: 32
                )
                Text(category.name)
                    .foregroundColor(.primary)
                Spacer()
                if category.isBuiltIn || BuiltinCategories.builtInCategoryIds.contains(category.id) {
                    Text("Built-in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !category.isDeletionProtected {
                Button(role: .destructive) {
                    Task { await deleteCategory(category) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func deleteCategory(_ category: CategoryDefinition) async {
        do {
            try await categoryStore.softDelete(id: category.id)
        } catch {
            deleteError = error.localizedDescription
            showDeleteError = true
        }
    }
}
