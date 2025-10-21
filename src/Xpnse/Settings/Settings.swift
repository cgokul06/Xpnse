//
//  Settings.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI

struct Settings: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCurrency: String = CurrencyManager.shared.selectedCurrency.code

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Currency Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Preferences")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    HStack(alignment: .center, spacing: 0) {
                        Text("Currency")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)

                        Spacer()

                        Picker("Currency", selection: $selectedCurrency) {
                            ForEach(CurrencyManager.shared.currencies) { currency in
                                Text(currency.displayName)
                                    .font(.system(size: 20, weight: .bold))
                                    .tag(currency.code)
                            }
                        }
                        .font(.system(size: 20, weight: .bold))
                        .pickerStyle(.menu)
                        .onChange(of: selectedCurrency, { oldValue, newValue in
                            if let selected = CurrencyManager.shared.currency(for: newValue) {
                                CurrencyManager.shared.selectedCurrency = selected
                            }
                        })
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Logout Section
                VStack {
                    Button(role: .destructive) {
                        self.appCoordinator.signOut()
                    } label: {
                        Text("Logout")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding()
        }
        .gradientNavigationBackground()
        .safeAreaInset(edge: .bottom, content: {
            Text("Version: 0.0.0")
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 20)
        })
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    self.dismiss()
                }, label: {
                    Image(systemName: "xmark")
                        .bold()
                        .padding(.all, 8)
                })
                .foregroundStyle(Color.white)
            }

            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .navigationBarBackButtonHidden()
    }
}
