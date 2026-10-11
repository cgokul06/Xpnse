//
//  EducationPolicyStateStore.swift
//  Xpnse
//

import Foundation

/// Persistence for global education policy, independent of campaign state.
protocol EducationPolicyStateStore: Sendable {
    func load() -> EducationPolicyState?
    func save(_ state: EducationPolicyState)
}

/// Persists `EducationPolicyState` in `UserDefaults`.
final class UserDefaultsEducationPolicyStateStore: EducationPolicyStateStore, @unchecked Sendable {
    static let defaultKey = "education.policy.state"

    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        key: String = UserDefaultsEducationPolicyStateStore.defaultKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> EducationPolicyState? {
        lock.lock()
        defer { lock.unlock() }

        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(EducationPolicyState.self, from: data)
    }

    func save(_ state: EducationPolicyState) {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }
}
