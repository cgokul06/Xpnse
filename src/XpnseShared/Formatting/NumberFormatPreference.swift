//
//  NumberFormatPreference.swift
//  XpnseShared
//

import Foundation

/// User preference for compact number abbreviation. Stored in the App Group suite
/// so both the app and widgets resolve the same style.
enum NumberFormatPreference: String, CaseIterable, Sendable {
    case auto
    case lakhCrore
    case million

    static let storageKey = "numberFormatPreference"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroupConstants.identifier) ?? .standard
    }

    static var current: NumberFormatPreference {
        guard let raw = defaults.string(forKey: storageKey) else {
            return .auto
        }
        return Self.fromStorage(raw)
    }

    static func set(_ preference: NumberFormatPreference) {
        defaults.set(preference.rawValue, forKey: storageKey)
    }

    /// Resolved abbreviation style for the current preference + device locale.
    var resolvedStyle: AmountFormattingStyle {
        switch self {
        case .lakhCrore:
            return .lakhCrore
        case .million:
            return .million
        case .auto:
            return Self.style(for: Locale.current)
        }
    }

    static func style(for locale: Locale) -> AmountFormattingStyle {
        switch locale.region?.identifier.uppercased() {
        case "IN":
            return .lakhCrore
        default:
            return .million
        }
    }

    /// Maps persisted values, including legacy geography-based keys.
    private static func fromStorage(_ raw: String) -> NumberFormatPreference {
        switch raw {
        case NumberFormatPreference.auto.rawValue:
            return .auto
        case NumberFormatPreference.lakhCrore.rawValue, "indian":
            return .lakhCrore
        case NumberFormatPreference.million.rawValue, "international":
            return .million
        default:
            return .auto
        }
    }
}
