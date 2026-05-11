//
//  RecurringReminderScheduler.swift
//  Xpnse
//
//  Created by Gokul C on 09/05/26.
//

import Foundation
import UserNotifications
import UIKit

@MainActor
final class RecurringReminderScheduler: NSObject {
    static let shared = RecurringReminderScheduler()

    private let repository: RecurringRepository
    private let calendar: Calendar

    private override init() {
        self.repository = SwiftDataRecurringRepository.shared
        self.calendar = .current
        super.init()
    }

    func configureNotificationCenterDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func removePendingNotification(for recurringId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [recurringId.uuidString])
    }

    func cancelReminder(for recurringId: UUID) async {
        removePendingNotification(for: recurringId)
        await clearScheduledOccurrenceDate(recurringId: recurringId)
    }

    private func clearScheduledOccurrenceDate(recurringId: UUID) async {
        do {
            let all = try await repository.fetchAll()
            guard var item = all.first(where: { $0.id == recurringId }) else { return }
            item.notificationScheduledForOccurrenceDate = nil
            try await repository.upsert(item)
        } catch {
            // ignore persistence errors
        }
    }

    func handleRecurringSaved(_ recurring: RecurringTransaction) async {
        if !recurring.notificationReminderEnabled || recurring.state != .active {
            await cancelReminder(for: recurring.id)
            return
        }
        guard recurring.notificationReminderTime != nil else {
            await cancelReminder(for: recurring.id)
            return
        }
        guard let next = recurring.nextOccurrence else {
            await cancelReminder(for: recurring.id)
            return
        }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            return
        }

        await schedule(recurring: recurring, occurrenceDate: next)
    }

    func reconcileAllPendingReminders() async {
        do {
            let all = try await repository.fetchAll()
            let pending = await fetchPendingRequests()
            let byId = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })

            for recurring in all where recurring.state == .active
                && recurring.notificationReminderEnabled
                && recurring.notificationReminderTime != nil {

                guard let next = recurring.nextOccurrence else {
                    if byId[recurring.id.uuidString] != nil {
                        removePendingNotification(for: recurring.id)
                    }
                    continue
                }

                guard let reminderTime = recurring.notificationReminderTime else { continue }

                let expectedOccurrenceStart = calendar.startOfDay(for: next)
                let expectedFire = mergedFireDate(occurrenceDay: next, reminderTime: reminderTime)

                if let existing = byId[recurring.id.uuidString],
                   let scheduledFor = recurring.notificationScheduledForOccurrenceDate,
                   calendar.isDate(scheduledFor, inSameDayAs: expectedOccurrenceStart),
                   let trigger = existing.trigger as? UNCalendarNotificationTrigger,
                   let triggerDate = trigger.nextTriggerDate() {
                    if abs(triggerDate.timeIntervalSince1970 - expectedFire.timeIntervalSince1970) < 60 {
                        continue
                    }
                }

                await schedule(recurring: recurring, occurrenceDate: next)
            }
        } catch {
            // ignore
        }
    }

    func scheduleNextAfterNotificationDelivery(recurringId: UUID, afterOccurrenceStart: Date) async {
        do {
            let all = try await repository.fetchAll()
            guard let recurring = all.first(where: { $0.id == recurringId }) else { return }
            guard recurring.notificationReminderEnabled,
                  recurring.state == .active,
                  recurring.notificationReminderTime != nil else {
                await cancelReminder(for: recurringId)
                return
            }

            let afterDay = calendar.startOfDay(for: afterOccurrenceStart)
            guard let nextDay = recurring.recurrence.nextOccurrence(after: afterDay, calendar: calendar) else {
                await cancelReminder(for: recurringId)
                return
            }

            if let end = recurring.endDate, calendar.startOfDay(for: nextDay) > calendar.startOfDay(for: end) {
                await cancelReminder(for: recurringId)
                return
            }

            await schedule(recurring: recurring, occurrenceDate: nextDay)
        } catch {
            // ignore
        }
    }

    private func fetchPendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func mergedFireDate(occurrenceDay: Date, reminderTime: Date) -> Date {
        let dayStart = calendar.startOfDay(for: occurrenceDay)
        let timeParts = calendar.dateComponents([.hour, .minute, .second], from: reminderTime)
        return calendar.date(
            bySettingHour: timeParts.hour ?? 9,
            minute: timeParts.minute ?? 0,
            second: timeParts.second ?? 0,
            of: dayStart
        ) ?? dayStart
    }

    private func schedule(recurring: RecurringTransaction, occurrenceDate: Date) async {
        guard let reminderTime = recurring.notificationReminderTime else { return }

        var occurrenceForFire = occurrenceDate
        var fireDate = mergedFireDate(occurrenceDay: occurrenceForFire, reminderTime: reminderTime)
        let now = Date()

        if fireDate < now {
            let start = calendar.startOfDay(for: occurrenceForFire)
            guard let nextDay = recurring.recurrence.nextOccurrence(after: start, calendar: calendar) else {
                await cancelReminder(for: recurring.id)
                return
            }
            if let end = recurring.endDate, calendar.startOfDay(for: nextDay) > calendar.startOfDay(for: end) {
                await cancelReminder(for: recurring.id)
                return
            }
            occurrenceForFire = nextDay
            fireDate = mergedFireDate(occurrenceDay: nextDay, reminderTime: reminderTime)
        }

        if fireDate < now {
            await cancelReminder(for: recurring.id)
            return
        }

        let occurrenceStart = calendar.startOfDay(for: occurrenceForFire)

        var updated = recurring
        updated.notificationScheduledForOccurrenceDate = occurrenceStart

        let content = UNMutableNotificationContent()
        content.title = "Upcoming: \(recurring.title)"
        let symbol = CurrencyManager.shared.selectedCurrency.symbol
        content.body = "\(symbol)\(NSDecimalNumber(decimal: recurring.amount).stringValue)"
        content.sound = .default
        content.userInfo = [
            "recurringId": recurring.id.uuidString,
            "occurrenceDate": NSNumber(value: occurrenceStart.timeIntervalSince1970)
        ]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: recurring.id.uuidString, content: content, trigger: trigger)

        removePendingNotification(for: recurring.id)

        do {
            try await UNUserNotificationCenter.current().add(request)
            try await repository.upsert(updated)
        } catch {
            // ignore scheduling errors
        }
    }
}

extension RecurringReminderScheduler: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let idString = userInfo["recurringId"] as? String,
           let id = UUID(uuidString: idString),
           let timestamp = (userInfo["occurrenceDate"] as? NSNumber)?.doubleValue {
            let occurrenceStart = Date(timeIntervalSince1970: timestamp)
            Task { @MainActor in
                await self.scheduleNextAfterNotificationDelivery(recurringId: id, afterOccurrenceStart: occurrenceStart)
            }
        }
        completionHandler()
    }
}
