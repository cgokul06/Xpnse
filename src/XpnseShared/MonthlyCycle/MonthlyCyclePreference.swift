//
//  MonthlyCyclePreference.swift
//  XpnseShared
//

import Foundation

/// Persists the monthly cycle start day in the App Group suite so the app and
/// widgets resolve the same configuration. Missing values default to 1.
enum MonthlyCyclePreference {
    static let storageKey = "monthlyCycleStartDay"

    static var current: MonthlyCycleConfiguration {
        load(from: appGroupDefaults)
    }

    static func setStartDay(_ day: Int) {
        save(startDay: day, to: appGroupDefaults)
    }

    static func load(from defaults: UserDefaults) -> MonthlyCycleConfiguration {
        guard let raw = defaults.object(forKey: storageKey) as? Int else {
            return .calendarMonth
        }
        return .fixedStartDay(raw)
    }

    static func save(startDay: Int, to defaults: UserDefaults) {
        defaults.set(MonthlyCycleConfiguration.clampedStartDay(startDay), forKey: storageKey)
    }

    private static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: AppGroupConstants.identifier) ?? .standard
    }
}
