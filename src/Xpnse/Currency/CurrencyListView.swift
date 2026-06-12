//
//  CurrencyListView.swift
//  Xpnse
//
//  Created by Gokul C on 08/05/26.
//

import SwiftUI

struct CurrencyListView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedCurrencyCode: String
    let onSelect: (CurrencyOption) -> Void

    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool

    private var currencies: [CurrencyOption] {
        CurrencyManager.shared.currencies
    }

    private var filteredCurrencies: [CurrencyOption] {
        currencies.filter { $0.matchesSearchQuery(searchText) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if filteredCurrencies.isEmpty {
                    Text("No currencies found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredCurrencies) { currency in
                            Button {
                                onSelect(currency)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(currency.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("\(currency.symbol)  \(currency.code)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                    }

                                    Spacer(minLength: 0)

                                    if currency.code == selectedCurrencyCode {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 12)
                                .background(.white.opacity(currency.code == selectedCurrencyCode ? 0.2 : 0.1))
                                .xpnseRoundedCorner()
                            }
                            .id(currency.code)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .onAppear {
                scrollToSelected(using: proxy)
            }
        }
        .gradientNavigationBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ZStack {
                    if isSearching {
                        searchField
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    } else {
                        Text("Select Currency")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.25), value: isSearching)
            }

            ToolbarItem(placement: .primaryAction) {
                if !isSearching {
                    Button {
                        activateSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white)
                    }
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isSearching)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            TextField("Search by name, code, or symbol", text: $searchText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFieldFocused)

            Button {
                closeSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(XpnseColorKey.whiteWithAlphaFifteen.color)
        .xpnseRoundedCorner(strokeConfig: StrokeConfig(color: .whiteWithAlphaThirty, lineWidth: 2))
    }

    private func activateSearch() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isSearching = true
        }
        DispatchQueue.main.async {
            isSearchFieldFocused = true
        }
    }

    private func closeSearch() {
        if searchText.isEmpty {
            dismissSearchState()
        } else {
            searchText = ""
        }
    }

    private func dismissSearchState() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isSearching = false
            searchText = ""
        }
        isSearchFieldFocused = false
    }

    private func scrollToSelected(using proxy: ScrollViewProxy) {
        guard !isSearching else { return }
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard filteredCurrencies.contains(where: { $0.code == selectedCurrencyCode }) else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(selectedCurrencyCode, anchor: .center)
            }
        }
    }
}
