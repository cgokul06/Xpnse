//
//  UserDefaultsKey.swift
//  Xpnse
//
//  Created by Gokul C on 14/09/25.
//

import Foundation

/// All keys used in UserDefaults
enum UserDefaultsKey: String {
    case selectedCurrencyCode
    case calendarAggregator
    /// When true, Insights Top Spends ranks only non-recurring-generated expenses.
    case excludeRecurringFromTopSpends
    /// UUID for this app installation only (cleared on uninstall).
    case installationId
    /// Codable `ReviewState` blob for the user-satisfaction engine.
    case reviewState
}

/// Wrapper for UserDefaults
class UserDefaultsHelper {
    static let shared = UserDefaultsHelper()
    private let defaults: UserDefaults

    private init() {
        if let groupDefaults = UserDefaults(suiteName: AppGroupConstants.identifier) {
            defaults = groupDefaults
            migrateFromStandardIfNeeded(to: groupDefaults)
        } else {
            defaults = .standard
        }
    }

    // MARK: - Generic Methods

    func set<T>(_ value: T, forKey key: UserDefaultsKey) {
        defaults.set(value, forKey: key.rawValue)
    }

    func string(forKey key: UserDefaultsKey) -> String? {
        defaults.string(forKey: key.rawValue)
    }

    func bool(forKey key: UserDefaultsKey) -> Bool {
        defaults.bool(forKey: key.rawValue)
    }

    func integer(forKey key: UserDefaultsKey) -> Int {
        defaults.integer(forKey: key.rawValue)
    }

    func remove(forKey key: UserDefaultsKey) {
        defaults.removeObject(forKey: key.rawValue)
    }

    func data(forKey key: UserDefaultsKey) -> Data? {
        defaults.data(forKey: key.rawValue)
    }

    func setData(_ value: Data?, forKey key: UserDefaultsKey) {
        if let value {
            defaults.set(value, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    private func migrateFromStandardIfNeeded(to groupDefaults: UserDefaults) {
        let standard = UserDefaults.standard
        let keys: [UserDefaultsKey] = [
            .selectedCurrencyCode,
            .calendarAggregator,
            .excludeRecurringFromTopSpends,
            .installationId,
            .reviewState
        ]

        for key in keys {
            guard groupDefaults.object(forKey: key.rawValue) == nil,
                  let value = standard.object(forKey: key.rawValue)
            else { continue }

            groupDefaults.set(value, forKey: key.rawValue)
        }
    }
}
