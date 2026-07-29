//
//  RemoteConfigService.swift
//  Xpnse
//

import Foundation
import FirebaseRemoteConfig

@MainActor
final class RemoteConfigService {
    static let shared = RemoteConfigService()

    private let remoteConfig = RemoteConfig.remoteConfig()
    private var lastFetchAttempt: Date?
    private let minimumFetchIntervalForeground: TimeInterval = 12 * 60 * 60

    private init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 12 * 60 * 60
        #endif
        remoteConfig.configSettings = settings

        var defaults: [String: NSObject] = [:]
        for key in FeatureFlags.Key.allCases {
            defaults[key.rawValue] = NSNumber(value: key.defaultEnabled)
        }
        remoteConfig.setDefaults(defaults)
        applyActivatedValues()
    }

    func fetchAndActivateIfNeeded(force: Bool = false) async {
        if !force, let lastFetchAttempt,
           Date().timeIntervalSince(lastFetchAttempt) < minimumFetchIntervalForeground {
            return
        }
        lastFetchAttempt = Date()
        do {
            let status = try await remoteConfig.fetchAndActivate()
            applyActivatedValues()
            _ = status
        } catch {
            // Keep last-known / default flags; app remains usable offline.
            print("Remote Config fetch failed: \(error.localizedDescription)")
        }
    }

    private func applyActivatedValues() {
        var values: [FeatureFlags.Key: Bool] = [:]
        for key in FeatureFlags.Key.allCases {
            values[key] = remoteConfig.configValue(forKey: key.rawValue).boolValue
        }
        FeatureFlags.shared.apply(boolValues: values)
    }
}
