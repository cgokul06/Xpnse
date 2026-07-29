//
//  ManageCategoriesView.swift
//  Xpnse
//

import SwiftUI

struct ManageCategoriesView: View {
    @Environment(\.colorScheme) private var colorScheme
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

    private var savingsCategories: [CategoryDefinition] {
        categoryStore.categories(for: .savings)
    }

    var body: some View {
        List {
            Section("category.section.expense") {
                ForEach(expenseCategories) { category in
                    categoryRow(category)
                }
            }

            Section("category.section.savings") {
                ForEach(savingsCategories) { category in
                    categoryRow(category)
                }
            }

            Section("category.section.income") {
                ForEach(incomeCategories) { category in
                    categoryRow(category)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .gradientNavigationBackground()
        .navigationTitle("settings.categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                }
            }
        }
        .task {
            AppAnalytics.logScreen(AppAnalytics.Screen.manageCategories)
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
        .alert("category.delete_failed_title", isPresented: $showDeleteError) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    @ViewBuilder
    private func categoryRow(_ category: CategoryDefinition) -> some View {
        HStack(spacing: 12) {
            CategoryIconBadge(
                symbolName: category.symbolName,
                colorHex: category.colorHex,
                size: 32
            )
            Text(categoryStore.localizedName(for: category))
                .foregroundColor(.primary)
            Spacer(minLength: 0)
            if category.isBuiltIn || BuiltinCategories.builtInCategoryIds.contains(category.id) {
                Text("category.builtin_badge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            editingCategory = category
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !category.isDeletionProtected {
                Button(role: .destructive) {
                    Task { await deleteCategory(category) }
                } label: {
                    Label("common.delete", systemImage: "trash")
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
