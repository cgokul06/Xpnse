//
//  WidgetAppearanceStore.swift
//  XpnseShared
//

import Foundation
import UIKit

/// Persists the main app's Light/Dark preference into the App Group as a file
/// (same channel as widget snapshots). UserDefaults suite values are unreliable
/// across the widget process boundary; WidgetKit traits also stay dark on light
/// wallpapers, so we never fall back to `UITraitCollection` here.
enum WidgetAppearanceStore {
    private static let fileName = "widget-appearance.json"
    private static let prefersDarkKey = "prefersDark"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroupConstants.identifier)?
            .appendingPathComponent(fileName)
    }

    /// When unset, default to light. Widget traits are not trustworthy.
    static var prefersDark: Bool {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let prefersDark = json[prefersDarkKey] as? Bool
        else {
            return false
        }
        return prefersDark
    }

    static var hasStoredPreference: Bool {
        guard let fileURL else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    @discardableResult
    static func sync(from style: UIUserInterfaceStyle) -> Bool {
        let prefersDark = style == .dark
        sync(prefersDark: prefersDark)
        return prefersDark
    }

    static func sync(prefersDark: Bool) {
        guard let fileURL else { return }
        let payload: [String: Any] = [
            prefersDarkKey: prefersDark,
            "updatedAt": Int(Date().timeIntervalSince1970)
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload)
        else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
