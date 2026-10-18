//
//  WidgetReminderActivityStore.swift
//  XpnseShared
//

import Foundation

/// App Group JSON file. UserDefaults is unreliable across the widget process.
enum WidgetReminderActivityStore {
    static let fileName = "widget-reminder-activity.json"

    /// Unit tests point this at a temporary file. The app and widget leave it nil.
    static var fileURLOverride: URL?

    static func load() -> WidgetReminderActivity {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let activity = try? JSONDecoder().decode(WidgetReminderActivity.self, from: data) else {
            return .fresh
        }
        return activity
    }

    static func recordAppOpen(at date: Date, remindersEnabled: Bool) {
        var activity = load()
        activity.lastAppOpenAt = date
        activity.remindersEnabled = remindersEnabled
        save(activity)
    }

    static func recordExpenseSaved(at date: Date) {
        var activity = load()
        activity.lastExpenseSavedAt = date
        save(activity)
    }

    static func setRemindersEnabled(_ enabled: Bool) {
        var activity = load()
        activity.remindersEnabled = enabled
        save(activity)
    }

    static func restartAfterDataClear(at date: Date, remindersEnabled: Bool) {
        save(WidgetReminderActivity(
            lastAppOpenAt: date,
            lastExpenseSavedAt: nil,
            remindersEnabled: remindersEnabled
        ))
    }

    private static var fileURL: URL? {
        if let fileURLOverride { return fileURLOverride }
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroupConstants.identifier)?
            .appendingPathComponent(fileName)
    }

    private static func save(_ activity: WidgetReminderActivity) {
        guard let fileURL, let data = try? JSONEncoder().encode(activity) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
