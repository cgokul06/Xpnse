//
//  UserNotificationScheduling.swift
//  Xpnse
//

import Foundation
import UserNotifications

struct ScheduledNotificationSnapshot: Equatable, Sendable {
    var identifier: String
    var fireDate: Date?
    var title: String
    var body: String
    var userInfoKind: String?
}

struct DeliveredNotificationSnapshot: Equatable, Sendable {
    var identifier: String
    var deliveredAt: Date
}

protocol UserNotificationScheduling: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(
        identifier: String,
        title: String,
        body: String,
        userInfoKind: String,
        fireDate: Date,
        calendar: Calendar
    ) async throws
    func pending() async -> [ScheduledNotificationSnapshot]
    func removePending(withIdentifiers identifiers: [String]) async
    func delivered() async -> [DeliveredNotificationSnapshot]
    func removeDelivered(withIdentifiers identifiers: [String]) async
}

final class LiveUserNotificationCenter: UserNotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func add(
        identifier: String,
        title: String,
        body: String,
        userInfoKind: String,
        fireDate: Date,
        calendar: Calendar
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["kind": userInfoKind]

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await center.add(request)
    }

    func pending() async -> [ScheduledNotificationSnapshot] {
        let requests = await center.pendingNotificationRequests()
        return requests.map { request in
            let fireDate = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            return ScheduledNotificationSnapshot(
                identifier: request.identifier,
                fireDate: fireDate,
                title: request.content.title,
                body: request.content.body,
                userInfoKind: request.content.userInfo["kind"] as? String
            )
        }
    }

    func removePending(withIdentifiers identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func delivered() async -> [DeliveredNotificationSnapshot] {
        let notifications = await center.deliveredNotifications()
        return notifications.map {
            DeliveredNotificationSnapshot(identifier: $0.request.identifier, deliveredAt: $0.date)
        }
    }

    func removeDelivered(withIdentifiers identifiers: [String]) async {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
