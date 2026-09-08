//
//  UserDefaultsEducationCampaignStateStore.swift
//  Xpnse
//

import Foundation

/// Persists campaign lifecycle state in `UserDefaults`.
final class UserDefaultsEducationCampaignStateStore: EducationCampaignStateStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String
    private let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "education.campaign.state."
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    func load(campaignID: String) -> CampaignState? {
        lock.lock()
        defer { lock.unlock() }

        guard let data = defaults.data(forKey: storageKey(for: campaignID)) else {
            return nil
        }
        return try? JSONDecoder().decode(CampaignState.self, from: data)
    }

    func save(_ state: CampaignState) {
        lock.lock()
        defer { lock.unlock() }

        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey(for: state.campaignID))
    }

    private func storageKey(for campaignID: String) -> String {
        keyPrefix + campaignID
    }
}
