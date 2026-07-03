//
//  CurrencySelectionView.swift
//  Xpnse
//
//  Created by Gokul C on 07/05/26.
//

import SwiftUI

struct CurrencySelectionView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @Environment(\.colorScheme) private var colorScheme

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
                            .xpnseAdaptiveForeground()
                        Text("Set your preferred currency before you start tracking expenses.")
                            .font(.system(size: 16, weight: .medium))
                            .xpnseAdaptiveForeground(muted: true)
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
                                .xpnseAdaptiveForeground()
                            Spacer()
                            Text("\(CurrencyManager.shared.selectedCurrency.symbol) \(selectedCurrencyCode)")
                                .font(.system(size: 16, weight: .semibold))
                                .xpnseAdaptiveForeground()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .xpnseAdaptiveForeground(muted: true)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .background(AdaptiveBrandSurface.rowBackground(for: colorScheme))
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
