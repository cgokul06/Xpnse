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

    private var currencies: [CurrencyOption] {
        CurrencyManager.shared.currencies
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(currencies) { currency in
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
            .onAppear {
                scrollToSelected(using: proxy)
            }
        }
        .gradientNavigationBackground()
        .navigationTitle("Select Currency")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scrollToSelected(using proxy: ScrollViewProxy) {
        guard currencies.contains(where: { $0.code == selectedCurrencyCode }) else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(selectedCurrencyCode, anchor: .center)
            }
        }
    }
}

