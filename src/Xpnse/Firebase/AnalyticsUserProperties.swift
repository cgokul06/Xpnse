//
//  AnalyticsUserProperties.swift
//  Xpnse
//
//  Coarse, non-PII user properties. Counts are bucketed; no amounts or names.
//

import Foundation
import UserNotifications

enum AnalyticsUserProperties {
    private static var refreshTask: Task<Void, Never>?

    /// Coalesces bursts of refresh requests (for example a save followed by recurring processing).
    static func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await refreshNow()
        }
    }

    static func refreshNow(
        transactionRepository: TransactionRepository = SwiftDataTransactionRepository.shared,
        recurringRepository: RecurringRepository = SwiftDataRecurringRepository.shared
    ) async {
        let fetchedTransactions = try? await transactionRepository.fetchAll()
        if let fetchedTransactions {
            ActivationAnalytics.shared.checkBaseline(existingTransactionCount: fetchedTransactions.count)
        }
        let transactions = fetchedTransactions ?? []
        let recurring = (try? await recurringRepository.fetchAll()) ?? []
        let status = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
        apply(
            values(
                transactions: transactions,
                recurring: recurring,
                notificationStatus: status,
                appLockEnabled: AppLockController.shared.isEnabled,
                expenseCheckInEnabled: ExpenseReminderScheduler.shared.isEnabled
            )
        )
    }

    static func values(
        transactions: [Transaction],
        recurring: [RecurringTransaction],
        notificationStatus: UNAuthorizationStatus,
        appLockEnabled: Bool,
        expenseCheckInEnabled: Bool
    ) -> [String: String] {
        typealias Property = AppAnalytics.UserProperty
        return [
            Property.hasExpense: AppAnalytics.flag(transactions.contains { $0.type == .expense }),
            Property.hasIncome: AppAnalytics.flag(transactions.contains { $0.type == .income }),
            Property.hasRecurring: AppAnalytics.flag(recurring.contains { $0.state == .active }),
            Property.txnBucket: AppAnalytics.Bucket.txnCount(transactions.count),
            Property.notificationsAuthorized: notificationValue(notificationStatus),
            Property.appLockEnabled: AppAnalytics.flag(appLockEnabled),
            Property.expenseCheckIn: expenseCheckInEnabled ? "enabled" : "disabled"
        ]
    }

    static func notificationValue(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .ephemeral: return "yes"
        case .denied: return "no"
        case .provisional: return "provisional"
        case .notDetermined: return "unknown"
        @unknown default: return "unknown"
        }
    }

    private static func apply(_ values: [String: String]) {
        for (name, value) in values {
            AppAnalytics.logger.setUserProperty(value, forName: name)
        }
    }
}
