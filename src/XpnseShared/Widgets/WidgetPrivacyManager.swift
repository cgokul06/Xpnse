//
//  WidgetPrivacyManager.swift
//  XpnseShared
//

import Foundation
import WidgetKit

/// Persists widget privacy preference and temporary reveal window in the App Group
/// as a file (same channel as snapshots / appearance). UserDefaults suite values are
/// unreliable across the widget process boundary.
enum WidgetPrivacyManager {
    static let revealDuration: TimeInterval = 30

    private static let fileName = "widget-privacy.json"
    private static let enabledKey = "widgetPrivacyEnabled"
    private static let revealTimestampKey = "widgetRevealTimestamp"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroupConstants.identifier)?
            .appendingPathComponent(fileName)
    }

    // MARK: - Public API

    /// Defaults to `false` (widgets always show data).
    static var isEnabled: Bool {
        read()[enabledKey] as? Bool ?? false
    }

    static var shouldHideData: Bool {
        isEnabled && !isRevealActive
    }

    static var isRevealActive: Bool {
        guard isEnabled, let timestamp = revealTimestamp else { return false }
        return Date().timeIntervalSince1970 - timestamp < revealDuration
    }

    /// When reveal is active, the wall-clock moment it expires; otherwise `nil`.
    static var revealExpiresAt: Date? {
        guard isEnabled, let timestamp = revealTimestamp else { return nil }
        let expiry = Date(timeIntervalSince1970: timestamp + revealDuration)
        return expiry > Date() ? expiry : nil
    }

    static func setEnabled(_ enabled: Bool) {
        var payload = read()
        payload[enabledKey] = enabled
        if !enabled {
            payload.removeValue(forKey: revealTimestampKey)
        }
        write(payload)
    }

    static func reveal() {
        var payload = read()
        payload[enabledKey] = true
        payload[revealTimestampKey] = Date().timeIntervalSince1970
        write(payload)
    }

    static func hide() {
        var payload = read()
        payload.removeValue(forKey: revealTimestampKey)
        write(payload)
    }

    static func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Persistence

    private static var revealTimestamp: TimeInterval? {
        read()[revealTimestampKey] as? TimeInterval
    }

    private static func read() -> [String: Any] {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return json
    }

    private static func write(_ payload: [String: Any]) {
        guard let fileURL else { return }
        var mutable = payload
        mutable["updatedAt"] = Int(Date().timeIntervalSince1970)
        guard JSONSerialization.isValidJSONObject(mutable),
              let data = try? JSONSerialization.data(withJSONObject: mutable)
        else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
