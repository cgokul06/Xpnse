//
//  DropDownMenu.swift
//  Xpnse
//
//  Created by Gokul C on 26/10/25.
//

import SwiftUI

struct DropDownMenu: View {
    let options: [CategoryDefinition]

    var menuWdith: CGFloat = 250
    private let buttonHeight: CGFloat = 40
    /// Approximate closed header height (padding + label row).
    static let headerHeight: CGFloat = 64
    /// Extra scroll clearance reserved under an open menu for the bottom action bar.
    static let bottomBarClearance: CGFloat = 112
    var maxItemDisplayed: Int = 3
    var showsAddCategoryShortcut: Bool = false
    var onAddCategory: (() -> Void)?

    @Binding var selectedCategoryId: String
    @Binding var showDropdown: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var selectedCategory: CategoryDefinition {
        options.first(where: { $0.id == selectedCategoryId })
            ?? CategoryStore.shared.resolve(id: selectedCategoryId)
    }

    private var showsAddCategoryRow: Bool {
        showsAddCategoryShortcut && onAddCategory != nil
    }

    private var visibleOptionCount: Int {
        min(options.count, maxItemDisplayed)
    }

    private var expandedListHeight: CGFloat {
        let rowCount = visibleOptionCount + (showsAddCategoryRow ? 1 : 0)
        return buttonHeight * CGFloat(rowCount)
    }

    /// Closed header ≈ 64pt. Expanded adds the options list.
    private var layoutHeight: CGFloat {
        showDropdown ? Self.headerHeight + expandedListHeight : Self.headerHeight
    }

    /// Extra scroll-view height to reserve under the category row while the menu is open
    /// (bottom action bar clearance only — the menu itself already expands the row).
    static func scrollPadding(
        optionCount: Int,
        maxItemDisplayed: Int = 4
    ) -> CGFloat {
        _ = optionCount
        _ = maxItemDisplayed
        return bottomBarClearance
    }
    var body: some View {
        menuContent
            .frame(width: menuWdith, height: layoutHeight, alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .compositingGroup()
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.12),
                radius: showDropdown ? 10 : 0,
                y: showDropdown ? 4 : 0
            )
            .zIndex(showDropdown ? 200 : 100)
    }

    private var menuContent: some View {
        VStack(spacing: 0) {
            headerButton
            if showDropdown {
                optionsList
            }
        }
        .background(menuBackground)
        .overlay(menuBorder)
    }

    private var headerButton: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                self.hideKeyboard()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showDropdown.toggle()
                }
            }
        }, label: {
            HStack {
                HStack(spacing: 8) {
                    CategoryIconBadge(
                        symbolName: selectedCategory.symbolName,
                        colorHex: selectedCategory.colorHex,
                        size: 28
                    )
                    Text(selectedCategory.name)
                        .font(.system(size: 20, weight: .bold))
                        .xpnseAdaptiveForeground()
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .xpnseAdaptiveForeground(muted: true)
                    .rotationEffect(.degrees(showDropdown ? -180 : 0))
            }
        })
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(width: menuWdith, alignment: .leading)
    }

    private var optionsList: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                            optionRow(
                                option: option,
                                index: index,
                                isLast: index == options.count - 1
                            )
                            .id(option.id)
                        }
                    }
                }
                .scrollDisabled(options.count <= maxItemDisplayed)
                .frame(height: CGFloat(visibleOptionCount) * buttonHeight)
                .onAppear {
                    revealSelectedCategory(using: proxy)
                }
            }

            if showsAddCategoryRow {
                addCategoryRow
            }
        }
        .frame(height: expandedListHeight)
    }

    /// Starts at the top, then animates to the current selection so the list reads as scrollable.
    private func revealSelectedCategory(using proxy: ScrollViewProxy) {
        guard options.count > maxItemDisplayed else { return }
        guard options.contains(where: { $0.id == selectedCategoryId }) else { return }
        DispatchQueue.main.async {
            if let first = options.first?.id {
                proxy.scrollTo(first, anchor: .top)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    proxy.scrollTo(selectedCategoryId, anchor: .center)
                }
            }
        }
    }

    private func optionRow(option: CategoryDefinition, index: Int, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut) {
                    selectedCategoryId = option.id
                    showDropdown.toggle()
                }
            }, label: {
                HStack {
                    HStack(spacing: 8) {
                        CategoryIconBadge(
                            symbolName: option.symbolName,
                            colorHex: option.colorHex,
                            size: 24
                        )
                        Text(option.name)
                            .font(.system(size: 18, weight: .semibold))
                            .xpnseAdaptiveForeground()
                    }
                    Spacer()
                    if option.id == selectedCategoryId {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(
                                AdaptiveBrandSurface.primaryForeground(for: colorScheme)
                            )
                    }
                }
            })
            .padding(.horizontal, 12)
            .frame(width: menuWdith, height: buttonHeight, alignment: .leading)

            if !isLast {
                Rectangle()
                    .fill(AdaptiveBrandSurface.fieldBorder(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
                    .padding(.horizontal, 12)
            }
        }
    }

    private var addCategoryRow: some View {
        VStack(spacing: 0) {
            if !options.isEmpty {
                Rectangle()
                    .fill(AdaptiveBrandSurface.fieldBorder(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
                    .padding(.horizontal, 12)
            }

            Button(action: {
                withAnimation(.easeInOut) {
                    showDropdown = false
                    onAddCategory?()
                }
            }, label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                    Text("category.new")
                        .font(.system(size: 18, weight: .semibold))
                        .xpnseAdaptiveForeground()
                    Spacer()
                }
            })
            .padding(.horizontal, 12)
            .frame(width: menuWdith, height: buttonHeight, alignment: .leading)
        }
    }

    private var menuBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(AdaptiveBrandSurface.dropdownSurfaceBackground(for: colorScheme))
    }

    private var menuBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(AdaptiveBrandSurface.fieldBorder(for: colorScheme), lineWidth: 2)
    }
}
