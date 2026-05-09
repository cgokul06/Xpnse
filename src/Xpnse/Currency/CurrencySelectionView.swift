//
//  CurrencySelectionView.swift
//  Xpnse
//
//  Created by Gokul C on 07/05/26.
//

import SwiftUI

struct CurrencySelectionView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator

    @State private var selectedCurrencyCode: String = CurrencyManager.shared.selectedCurrency.code
    @State private var didSelectCurrency = false

    var body: some View {
        NavigationStack {
            ZStack {
                PrimaryGradient()

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose your currency")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("Set your preferred currency before you start tracking expenses.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    NavigationLink {
                        CurrencyListView(selectedCurrencyCode: selectedCurrencyCode) { selected in
                            selectedCurrencyCode = selected.code
                            CurrencyManager.shared.selectedCurrency = selected
                            didSelectCurrency = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text("Currency")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(CurrencyManager.shared.selectedCurrency.symbol) \(selectedCurrencyCode)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.12))
                        .xpnseRoundedCorner()
                    }

                    Spacer()

                    Button {
                        if let selected = CurrencyManager.shared.currency(for: selectedCurrencyCode) {
                            CurrencyManager.shared.selectedCurrency = selected
                        }
                        appCoordinator.navigateToHome()
                    } label: {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(XpnseColorKey.secondaryButtonBGColor.color)
                            .xpnseRoundedCorner()
                    }
                    .disabled(!didSelectCurrency)
                    .opacity(didSelectCurrency ? 1.0 : 0.7)
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

