//
//  ExpenseReminderPolicy.swift
//  Xpnse
//

import Foundation
import UserNotifications

/// Single configuration point for the inactivity expense reminder.
struct ExpenseReminderPolicy: Equatable, Sendable {
    /// Release schedule: 24 hours of inactivity, then the next local 7:00 PM.
    static let current = ExpenseReminderPolicy()

    /// Debug schedule: one notification 30 minutes after the app leaves the foreground.
    static let debug: ExpenseReminderPolicy = {
        var policy = ExpenseReminderPolicy()
        policy.inactivityThreshold = 30 * 60
        policy.deliversAtNextEvening = false
        return policy
    }()

    /// Policy used by the running app. Debug builds use the 30-minute schedule.
    static var runtime: ExpenseReminderPolicy {
        #if DEBUG
        return debug
        #else
        return current
        #endif
    }

    var campaignVersion: Int = 1
    /// Elapsed inactivity before a reminder may fire. Release builds then wait for the next 7:00 PM.
    var inactivityThreshold: TimeInterval = 24 * 60 * 60
    /// When false, the reminder fires `inactivityThreshold` after the scheduling moment.
    var deliversAtNextEvening: Bool = true
    var reminderHour: Int = 19
    var reminderMinute: Int = 0
    var notificationIdentifier: String = "snapledger.expense-reminder"

    static let userInfoKind = "expenseReminder"
    static let analyticsNotificationType = "expense_check_in"

    static let titleKey = "notification.expense_reminder.title"
    static let bodyKey = "notification.expense_reminder.body"
}

enum ExpenseReminderPhase: Equatable, Sendable {
    case inactive
    case waitingForInactivity
    case scheduled
    case delivered
    case suppressed
}

enum ExpenseReminderAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown

    var permitsScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied, .unknown:
            return false
        }
    }

    init(status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .unknown
        }
    }
}

enum ExpenseReminderCancellationReason {
    static let appOpen = "app_open"
    static let disabled = "disabled"
    static let authorizationDenied = "authorization_denied"
    static let policyChanged = "policy_changed"
    static let rescheduled = "rescheduled"
    static let inactive = "inactive"
}

struct ExpenseReminderEvaluation: Equatable, Sendable {
    var isEnabled: Bool
    var hasCompletedFirstUse: Bool
    var authorization: ExpenseReminderAuthorization
    var isForeground: Bool
    var lastActiveAt: Date?
    var now: Date
    var hasPendingReminder: Bool
    var lastReminderDeliveredAt: Date?
}

struct ExpenseReminderDecision: Equatable, Sendable {
    var phase: ExpenseReminderPhase
    var shouldSchedule: Bool
    var shouldCancel: Bool
    var cancellationReason: String?
    var fireDate: Date?
}

enum ExpenseReminderScheduleMath {
    /// Next local reminder time at or after `lastActiveAt + inactivity`, and strictly after `now`.
    static func nextFireDate(
        lastActiveAt: Date,
        now: Date,
        policy: ExpenseReminderPolicy,
        calendar: Calendar
    ) -> Date? {
        if !policy.deliversAtNextEvening {
            return now.addingTimeInterval(policy.inactivityThreshold)
        }
        let eligibleAt = lastActiveAt.addingTimeInterval(policy.inactivityThreshold)
        let earliest = max(eligibleAt, now.addingTimeInterval(1))
        return nextLocalReminderTime(onOrAfter: earliest, policy: policy, calendar: calendar)
    }

    static func nextLocalReminderTime(
        onOrAfter instant: Date,
        policy: ExpenseReminderPolicy,
        calendar: Calendar
    ) -> Date? {
        let day = calendar.startOfDay(for: instant)
        guard let sameDay = reminderTime(onDayStarting: day, policy: policy, calendar: calendar) else {
            return nil
        }
        if sameDay >= instant {
            return sameDay
        }
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        return reminderTime(onDayStarting: nextDay, policy: policy, calendar: calendar)
    }

    private static func reminderTime(
        onDayStarting day: Date,
        policy: ExpenseReminderPolicy,
        calendar: Calendar
    ) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = policy.reminderHour
        components.minute = policy.reminderMinute
        components.second = 0
        return calendar.date(from: components)
    }
}

enum ExpenseReminderEvaluator {
    static func decide(
        _ input: ExpenseReminderEvaluation,
        policy: ExpenseReminderPolicy,
        calendar: Calendar
    ) -> ExpenseReminderDecision {
        if !input.isEnabled {
            return ExpenseReminderDecision(
                phase: .inactive,
                shouldSchedule: false,
                shouldCancel: input.hasPendingReminder,
                cancellationReason: input.hasPendingReminder ? ExpenseReminderCancellationReason.disabled : nil,
                fireDate: nil
            )
        }

        if !input.hasCompletedFirstUse {
            return ExpenseReminderDecision(
                phase: .inactive,
                shouldSchedule: false,
                shouldCancel: input.hasPendingReminder,
                cancellationReason: input.hasPendingReminder ? ExpenseReminderCancellationReason.inactive : nil,
                fireDate: nil
            )
        }

        if !input.authorization.permitsScheduling {
            return ExpenseReminderDecision(
                phase: .suppressed,
                shouldSchedule: false,
                shouldCancel: input.hasPendingReminder,
                cancellationReason: input.hasPendingReminder ? ExpenseReminderCancellationReason.authorizationDenied : nil,
                fireDate: nil
            )
        }

        guard let lastActiveAt = input.lastActiveAt else {
            return ExpenseReminderDecision(
                phase: .waitingForInactivity,
                shouldSchedule: false,
                shouldCancel: false,
                cancellationReason: nil,
                fireDate: nil
            )
        }

        let fireDate = ExpenseReminderScheduleMath.nextFireDate(
            lastActiveAt: lastActiveAt,
            now: input.now,
            policy: policy,
            calendar: calendar
        )

        if let deliveredAt = input.lastReminderDeliveredAt, deliveredAt > lastActiveAt {
            return ExpenseReminderDecision(
                phase: .delivered,
                shouldSchedule: false,
                shouldCancel: input.hasPendingReminder,
                cancellationReason: input.hasPendingReminder ? ExpenseReminderCancellationReason.rescheduled : nil,
                fireDate: nil
            )
        }

        if input.isForeground {
            return ExpenseReminderDecision(
                phase: input.hasPendingReminder ? .scheduled : .waitingForInactivity,
                shouldSchedule: false,
                shouldCancel: input.hasPendingReminder,
                cancellationReason: input.hasPendingReminder ? ExpenseReminderCancellationReason.appOpen : nil,
                fireDate: fireDate
            )
        }

        guard let fireDate else {
            return ExpenseReminderDecision(
                phase: .waitingForInactivity,
                shouldSchedule: false,
                shouldCancel: false,
                cancellationReason: nil,
                fireDate: nil
            )
        }

        return ExpenseReminderDecision(
            phase: .scheduled,
            shouldSchedule: true,
            shouldCancel: false,
            cancellationReason: nil,
            fireDate: fireDate
        )
    }
}
