//
//  RecurringReminderScheduleMath.swift
//  Xpnse
//

import Foundation

/// Fire time for each occurrence is `endOfCalendarDay(occurrenceDay) - offset`.
enum RecurringReminderScheduleMath {
    /// Last moment of the calendar day containing `date` (23:59:59 in `calendar`).
    static func endOfCalendarDay(containing date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return date
        }
        return nextMidnight.addingTimeInterval(-1)
    }

    /// Last moment of the calendar day **before** the transaction day (e.g. transaction 11 May → 10 May 23:59:59).
    static func endOfDayBeforeTransactionDay(containing transactionDay: Date, calendar: Calendar = .current) -> Date? {
        let txStart = calendar.startOfDay(for: transactionDay)
        guard let previousDayStart = calendar.date(byAdding: .day, value: -1, to: txStart) else { return nil }
        return endOfCalendarDay(containing: previousDayStart, calendar: calendar)
    }

    /// Seconds from `reminderDateTime` to the end of the **transaction** calendar day (positive when the reminder is earlier).
    static func offsetFromEndOfTransactionDay(
        transactionDay: Date,
        reminderDateTime: Date,
        calendar: Calendar = .current
    ) -> TimeInterval {
        let end = endOfCalendarDay(containing: transactionDay, calendar: calendar)
        return end.timeIntervalSince(reminderDateTime)
    }

    /// Reminder must fall strictly **before** the transaction calendar day (latest: end of the previous day).
    static func isValidReminder(
        transactionDay: Date,
        reminderDateTime: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let latestAllowed = endOfDayBeforeTransactionDay(containing: transactionDay, calendar: calendar) else {
            return false
        }
        return reminderDateTime <= latestAllowed
    }

    static func fireDateForOccurrence(
        occurrenceDay: Date,
        offsetFromEndOfTransactionDay: TimeInterval,
        calendar: Calendar = .current
    ) -> Date {
        let end = endOfCalendarDay(containing: occurrenceDay, calendar: calendar)
        return end.addingTimeInterval(-offsetFromEndOfTransactionDay)
    }

    /// Derive offset from pre-offset backups that stored only a wall-clock time on the start day.
    static func offsetFromLegacyNotificationTime(
        _ legacyWallTime: Date,
        transactionStartDay: Date,
        calendar: Calendar = .current
    ) -> TimeInterval? {
        let dayStart = calendar.startOfDay(for: transactionStartDay)
        let parts = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: legacyWallTime)
        guard let merged = calendar.date(
            bySettingHour: parts.hour ?? 0,
            minute: parts.minute ?? 0,
            second: parts.second ?? 0,
            of: dayStart
        ) else {
            return nil
        }
        let end = endOfCalendarDay(containing: transactionStartDay, calendar: calendar)
        let offset = end.timeIntervalSince(merged)
        return offset >= 0 ? offset : nil
    }
}
