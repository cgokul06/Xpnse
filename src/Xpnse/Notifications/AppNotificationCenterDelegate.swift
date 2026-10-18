//
//  AppNotificationCenterDelegate.swift
//  Xpnse
//

import Foundation
import UserNotifications

/// Single notification-center delegate. Recurring reminders and the expense check-in
/// share one center, and each handles only its own payload.
final class AppNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationCenterDelegate()

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

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
        let request = response.notification.request
        let userInfo = request.content.userInfo
        let identifier = request.identifier
        Task { @MainActor in
            if identifier == ExpenseReminderPolicy.current.notificationIdentifier
                || userInfo["kind"] as? String == ExpenseReminderPolicy.userInfoKind {
                await ExpenseReminderScheduler.shared.handleNotificationOpened()
            } else {
                AppAnalytics.logEvent(AppAnalytics.Event.checkInOpened, parameters: [
                    AppAnalytics.Param.entryPoint: "notification",
                    AppAnalytics.Param.notificationType: "recurring_reminder"
                ])
                RecurringReminderScheduler.shared.handleNotificationResponse(userInfo: userInfo)
            }
        }
        completionHandler()
    }
}
