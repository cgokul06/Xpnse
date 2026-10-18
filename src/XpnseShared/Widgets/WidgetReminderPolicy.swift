//
//  WidgetReminderPolicy.swift
//  XpnseShared
//

import Foundation

/// Balance-widget check-in. Gentle and overdue share copy; only the wait differs.
enum WidgetReminderState: Equatable, Sendable {
    case normal
    case gentleReminder
    case overdueReminder
}

struct WidgetReminderPolicy: Equatable, Sendable {
    /// Release: gentle after 24 hours, overdue after 48 hours, and the same calendar day stays normal.
    static let production = WidgetReminderPolicy()

    /// Debug: version 1 after 30 minutes, version 2 after 1 hour, including later the same day.
    static let debug = WidgetReminderPolicy(
        gentleAfter: 30 * 60,
        overdueAfter: 60 * 60,
        suppressesSameCalendarDay: false
    )

    static var runtime: WidgetReminderPolicy {
        #if DEBUG
        return debug
        #else
        return production
        #endif
    }

    var gentleAfter: TimeInterval = 24 * 60 * 60
    var overdueAfter: TimeInterval = 48 * 60 * 60
    /// A daylight-saving fallback can make one calendar day last about 25 hours.
    var suppressesSameCalendarDay: Bool = true
}

struct WidgetReminderActivity: Codable, Equatable, Sendable {
    var lastAppOpenAt: Date?
    var lastExpenseSavedAt: Date?
    var remindersEnabled: Bool

    static let fresh = WidgetReminderActivity(
        lastAppOpenAt: nil,
        lastExpenseSavedAt: nil,
        remindersEnabled: true
    )

    var activityAt: Date? {
        switch (lastAppOpenAt, lastExpenseSavedAt) {
        case let (opened?, saved?):
            return max(opened, saved)
        case let (opened?, nil):
            return opened
        case let (nil, saved?):
            return saved
        case (nil, nil):
            return nil
        }
    }
}

enum WidgetReminderEvaluator {
    static func state(
        activity: WidgetReminderActivity,
        now: Date,
        policy: WidgetReminderPolicy = .production,
        calendar: Calendar
    ) -> WidgetReminderState {
        guard activity.remindersEnabled, let activityAt = activity.activityAt else { return .normal }
        let gentleAt = gentleBoundary(activity: activity, activityAt: activityAt, policy: policy, calendar: calendar)
        let overdueAt = overdueBoundary(activityAt: activityAt, gentleAt: gentleAt, policy: policy)
        if now < gentleAt { return .normal }
        if now < overdueAt { return .gentleReminder }
        return .overdueReminder
    }

    /// Transition dates strictly after `now`. Reading these does not write the activity file.
    static func transitionDates(
        activity: WidgetReminderActivity,
        now: Date,
        policy: WidgetReminderPolicy = .production,
        calendar: Calendar
    ) -> [Date] {
        guard activity.remindersEnabled, let activityAt = activity.activityAt else { return [] }
        let gentleAt = gentleBoundary(activity: activity, activityAt: activityAt, policy: policy, calendar: calendar)
        let overdueAt = overdueBoundary(activityAt: activityAt, gentleAt: gentleAt, policy: policy)
        var dates: [Date] = []
        if gentleAt > now { dates.append(gentleAt) }
        if overdueAt > now, overdueAt != gentleAt { dates.append(overdueAt) }
        return dates
    }

    private static func gentleBoundary(
        activity: WidgetReminderActivity,
        activityAt: Date,
        policy: WidgetReminderPolicy,
        calendar: Calendar
    ) -> Date {
        let elapsed = activityAt.addingTimeInterval(policy.gentleAfter)
        guard policy.suppressesSameCalendarDay, let opened = activity.lastAppOpenAt else { return elapsed }
        let start = calendar.startOfDay(for: opened)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: start) else { return elapsed }
        return max(elapsed, nextDay)
    }

    private static func overdueBoundary(
        activityAt: Date,
        gentleAt: Date,
        policy: WidgetReminderPolicy
    ) -> Date {
        max(activityAt.addingTimeInterval(policy.overdueAfter), gentleAt)
    }
}

enum WidgetReminderLink {
    static let familyQueryName = "family"

    static func addExpenseURL(family: String) -> URL {
        URL(string: "\(AppGroupConstants.urlScheme)://add-transaction?\(familyQueryName)=\(family)")!
    }
}
