//
//  CurrencyManager.swift
//  Xpnse
//
//  Created by Gokul C on 14/09/25.
//

import Foundation
import Combine

final class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()
    private(set) var currencies: [CurrencyOption] = []
    @Published var selectedCurrency: CurrencyOption {
        didSet {
            UserDefaultsHelper.shared.set(selectedCurrency.code, forKey: .selectedCurrencyCode)
            Task { await WidgetRefreshCoordinator.shared.refresh() }
        }
    }

    private let defaultCode = "USD"   // ✅ fallback if nothing saved
    private var defaultCurrency: CurrencyOption? {
        currencies.first { $0.code == defaultCode }
    }

    init() {
        let loadedCurrencies = CurrencyManager.loadCurrencies()
        self.currencies = loadedCurrencies
        self.selectedCurrency = CurrencyManager.resolveInitialCurrency(from: loadedCurrencies, defaultCode: "USD")
    }

    var hasStoredSelection: Bool {
        UserDefaultsHelper.shared.string(forKey: .selectedCurrencyCode) != nil
    }

    /// Lookup helper
    func currency(for code: String) -> CurrencyOption? {
        currencies.first { $0.code == code }
    }

    /// Loads from JSON in app bundle
    private static func loadCurrencies() -> [CurrencyOption] {
        if let url = Bundle.main.url(forResource: "Currencies", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([CurrencyOption].self, from: data) {
            return decoded
        }
        return []
    }

    private static func resolveInitialCurrency(from currencies: [CurrencyOption], defaultCode: String) -> CurrencyOption {
        if let code = UserDefaultsHelper.shared.string(forKey: .selectedCurrencyCode),
           let saved = currencies.first(where: { $0.code == code }) {
            return saved
        }

        if let fallback = currencies.first(where: { $0.code == defaultCode }) ?? currencies.first {
            return fallback
        }

        return CurrencyOption(
            id: 145,
            code: "USD",
            name: "Dollars",
            symbol: "$"
        )
    }
}
