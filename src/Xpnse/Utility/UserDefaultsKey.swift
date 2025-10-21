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
}

/// Wrapper for UserDefaults
class UserDefaultsHelper {
    static let shared = UserDefaultsHelper()
    private let defaults = UserDefaults.standard
    
    private init() {}
    
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
}
