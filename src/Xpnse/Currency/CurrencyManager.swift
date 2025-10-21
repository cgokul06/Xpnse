//
//  CurrencyManager.swift
//  Xpnse
//
//  Created by Gokul C on 14/09/25.
//

import Foundation

class CurrencyManager {
    static let shared = CurrencyManager()
    private(set) var currencies: [CurrencyOption] = []

    private let defaultCode = "USD"   // ✅ fallback if nothing saved
    private var defaultCurrency: CurrencyOption? {
        currencies.first { $0.code == defaultCode }
    }

    init() {
        loadCurrencies()
    }

    /// Loads from JSON in app bundle
    private func loadCurrencies() {
        if let url = Bundle.main.url(forResource: "Currencies", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([CurrencyOption].self, from: data) {
            self.currencies = decoded
        }
    }

    /// Currently selected currency (auto-saves to UserDefaults)
    var selectedCurrency: CurrencyOption {
        get {
            if let code = UserDefaultsHelper.shared.string(forKey: .selectedCurrencyCode),
               let saved = currencies.first(where: { $0.code == code }) {
                return saved
            }
            return defaultCurrency ?? currencies.first ?? CurrencyOption(
                id: 145,
                code: "USD",
                name: "Dollars",
                symbol: "$"
            )
        }
        set {
            UserDefaultsHelper.shared.set(newValue.code, forKey: .selectedCurrencyCode)
        }
    }

    /// Lookup helper
    func currency(for code: String) -> CurrencyOption? {
        currencies.first { $0.code == code }
    }
}
