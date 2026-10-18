//
//  ExpenseReminderScheduler.swift
//  Xpnse
//

import Foundation
import UserNotifications

@MainActor
final class ExpenseReminderScheduler {
    static let shared = ExpenseReminderScheduler(
        store: UserDefaultsExpenseReminderStore(),
        notifications: LiveUserNotificationCenter(),
        clock: SystemClock(),
        calendarProvider: { Calendar.current },
        policy: .runtime,
        hasCompletedFirstUse: { CurrencyManager.shared.hasStoredSelection },
        openAddExpense: { AppDeepLinkRouter.shared.requestAddExpenseIfAtRoot() },
        observesTimeZoneChanges: true,
        widgetActivity: LiveWidgetReminderActivityRecorder()
    )

    private let store: ExpenseReminderStoring
    private let notifications: UserNotificationScheduling
    private let clock: Clock
    private let calendarProvider: () -> Calendar
    private let policy: ExpenseReminderPolicy
    private let analyticsOverride: AnalyticsLogging?
    private var analytics: AnalyticsLogging { analyticsOverride ?? AppAnalytics.logger }
    private let hasCompletedFirstUse: () -> Bool
    private let openAddExpense: () -> Void
    private let widgetActivity: WidgetReminderActivityRecording

    private var didRecordActivityThisSession = false
    private var isForeground = false
    private var didLogOpenThisSession = false
    private var tail: Task<Void, Never>?
    private var timeZoneObserver: NSObjectProtocol?

    var isEnabled: Bool { store.isEnabled }

    init(
        store: ExpenseReminderStoring,
        notifications: UserNotificationScheduling,
        clock: Clock,
        calendarProvider: @escaping () -> Calendar,
        policy: ExpenseReminderPolicy = .current,
        analytics: AnalyticsLogging? = nil,
        hasCompletedFirstUse: @escaping () -> Bool,
        openAddExpense: @escaping () -> Void,
        observesTimeZoneChanges: Bool = false,
        widgetActivity: WidgetReminderActivityRecording = NoOpWidgetReminderActivityRecorder()
    ) {
        self.store = store
        self.notifications = notifications
        self.clock = clock
        self.calendarProvider = calendarProvider
        self.policy = policy
        self.analyticsOverride = analytics
        self.hasCompletedFirstUse = hasCompletedFirstUse
        self.openAddExpense = openAddExpense
        self.widgetActivity = widgetActivity
        if observesTimeZoneChanges {
            timeZoneObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NSSystemTimeZoneDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.reconcileSchedule()
                }
            }
        }
    }

    func handleDidBecomeActive() async {
        await perform { await self.didBecomeActiveLocked() }
    }

    func handleDidEnterBackground() async {
        await perform { await self.didEnterBackgroundLocked() }
    }

    func requestProvisionalAuthorizationIfNeeded() async {
        await perform { await self.requestProvisionalLocked() }
    }

    func reconcileSchedule() async {
        await perform {
            guard !self.isForeground else { return }
            await self.scheduleIfNeededLocked()
        }
    }

    func setEnabled(_ enabled: Bool) async {
        await perform {
            self.store.isEnabled = enabled
            self.widgetActivity.setRemindersEnabled(enabled)
            WidgetTimelineReloader.reloadBalance()
            guard !enabled else { return }
            await self.cancelIfPending(reason: ExpenseReminderCancellationReason.disabled)
        }
    }

    /// A later tap restarts the window and replaces the earlier marker; one conversion per marker.
    static let conversionWindow: TimeInterval = 24 * 60 * 60

    func handleNotificationOpened() async {
        await perform {
            self.store.conversionAttribution = ExpenseReminderConversionAttribution(
                campaignVersion: self.policy.campaignVersion,
                expiresAt: self.clock.now().addingTimeInterval(Self.conversionWindow)
            )
            if !self.didLogOpenThisSession {
                self.didLogOpenThisSession = true
                self.analytics.log(
                    AppAnalytics.Event.checkInOpened,
                    parameters: self.parameters([
                        AppAnalytics.Param.entryPoint: "notification",
                        AppAnalytics.Param.notificationType: ExpenseReminderPolicy.analyticsNotificationType
                    ])
                )
            }
            self.openAddExpense()
        }
    }

    func noteExpenseAdded() async {
        await perform {
            guard let attribution = self.store.conversionAttribution else { return }
            self.store.conversionAttribution = nil
            guard self.clock.now() < attribution.expiresAt else { return }
            self.analytics.log(
                AppAnalytics.Event.checkInConversion,
                parameters: [
                    AppAnalytics.Param.campaignVersion: String(attribution.campaignVersion),
                    AppAnalytics.Param.entryPoint: "notification",
                    AppAnalytics.Param.actionType: "expense_saved",
                    AppAnalytics.Param.window: "24h"
                ]
            )
        }
    }

    /// Data wipe already removed every pending notification. Restart the inactivity window from now.
    func noteLocalDataCleared() async {
        await perform {
            let now = self.clock.now()
            self.store.lastActiveAt = now
            self.store.lastScheduledReminderAt = nil
            self.store.lastReminderDeliveredAt = nil
            self.store.conversionAttribution = nil
            self.widgetActivity.restartAfterDataClear(at: now, remindersEnabled: self.store.isEnabled)
            WidgetTimelineReloader.reloadBalance()
        }
    }

    private func didBecomeActiveLocked() async {
        isForeground = true
        if !didRecordActivityThisSession {
            didRecordActivityThisSession = true
            let now = clock.now()
            store.lastActiveAt = now
            widgetActivity.recordAppOpen(at: now, remindersEnabled: store.isEnabled)
        }
        await migrateCampaignVersionIfNeeded()
        await recordDeliveredIfPresent()
        await cancelIfPending(reason: ExpenseReminderCancellationReason.appOpen)
        await notifications.removeDelivered(withIdentifiers: [policy.notificationIdentifier])
    }

    private func didEnterBackgroundLocked() async {
        isForeground = false
        didRecordActivityThisSession = false
        didLogOpenThisSession = false
        await scheduleIfNeededLocked()
    }

    private func requestProvisionalLocked() async {
        guard hasCompletedFirstUse(), store.isEnabled else { return }
        guard !store.didAttemptProvisionalAuthorization else { return }
        await Task.yield()
        guard hasCompletedFirstUse(), store.isEnabled, !store.didAttemptProvisionalAuthorization else { return }

        let status = await notifications.authorizationStatus()
        switch status {
        case .notDetermined:
            // One attempt per install, whether the call grants provisional authorization or fails.
            store.didAttemptProvisionalAuthorization = true
            _ = try? await notifications.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
        case .authorized, .provisional, .ephemeral, .denied:
            store.didAttemptProvisionalAuthorization = true
        @unknown default:
            store.didAttemptProvisionalAuthorization = true
        }
    }

    private func migrateCampaignVersionIfNeeded() async {
        let stored = store.campaignVersion
        if stored == 0 {
            store.campaignVersion = policy.campaignVersion
            return
        }
        guard stored != policy.campaignVersion else { return }
        await cancelIfPending(reason: ExpenseReminderCancellationReason.policyChanged)
        store.campaignVersion = policy.campaignVersion
    }

    private func scheduleIfNeededLocked() async {
        let authorization = ExpenseReminderAuthorization(status: await notifications.authorizationStatus())
        let pending = await notifications.pending()
        let hasPending = pending.contains { $0.identifier == policy.notificationIdentifier }
        let calendar = calendarProvider()
        let decision = ExpenseReminderEvaluator.decide(
            ExpenseReminderEvaluation(
                isEnabled: store.isEnabled,
                hasCompletedFirstUse: hasCompletedFirstUse(),
                authorization: authorization,
                isForeground: isForeground,
                lastActiveAt: store.lastActiveAt,
                now: clock.now(),
                hasPendingReminder: hasPending,
                lastReminderDeliveredAt: store.lastReminderDeliveredAt
            ),
            policy: policy,
            calendar: calendar
        )

        if decision.shouldCancel, let reason = decision.cancellationReason {
            await cancelIfPending(reason: reason)
        }

        guard decision.shouldSchedule, let fireDate = decision.fireDate, !isForeground else { return }

        logOnce(
            event: AppAnalytics.Event.checkInEligible,
            signature: fireSignature(fireDate),
            parameters: [AppAnalytics.Param.triggerReason: "inactivity_24h"]
        )

        if let existing = pending.first(where: { $0.identifier == policy.notificationIdentifier }),
           let existingFire = existing.fireDate,
           abs(existingFire.timeIntervalSince(fireDate)) < 60 {
            store.lastScheduledReminderAt = fireDate
            return
        }

        if hasPending {
            let removed = await cancelIfPending(reason: ExpenseReminderCancellationReason.rescheduled)
            if !removed {
                let stillPending = await notifications.pending()
                if stillPending.contains(where: { $0.identifier == policy.notificationIdentifier }) {
                    return
                }
            }
        }

        do {
            try await notifications.add(
                identifier: policy.notificationIdentifier,
                title: L10n.tr(ExpenseReminderPolicy.titleKey),
                body: L10n.tr(ExpenseReminderPolicy.bodyKey),
                userInfoKind: ExpenseReminderPolicy.userInfoKind,
                fireDate: fireDate,
                calendar: calendar
            )
            store.lastScheduledReminderAt = fireDate
            logOnce(
                event: AppAnalytics.Event.checkInScheduleResult,
                signature: fireSignature(fireDate),
                parameters: [AppAnalytics.Param.result: AppAnalytics.Outcome.success.rawValue]
            )
        } catch {
            // Leave lastScheduledReminderAt unchanged when add did not replace a removed request.
            // A failed replacement already cleared it inside cancelIfPending, which is recoverable.
            logOnce(
                event: AppAnalytics.Event.checkInScheduleResult,
                signature: "failed|" + fireSignature(fireDate),
                parameters: [
                    AppAnalytics.Param.result: AppAnalytics.Outcome.failed.rawValue,
                    AppAnalytics.Param.failureReason: AppAnalytics.FailureReason.unexpected.rawValue
                ]
            )
        }
    }

    @discardableResult
    private func cancelIfPending(reason: String) async -> Bool {
        let pending = await notifications.pending()
        guard pending.contains(where: { $0.identifier == policy.notificationIdentifier }) else {
            return false
        }
        let scheduledAt = store.lastScheduledReminderAt
        await notifications.removePending(withIdentifiers: [policy.notificationIdentifier])
        let after = await notifications.pending()
        guard !after.contains(where: { $0.identifier == policy.notificationIdentifier }) else {
            return false
        }
        store.lastScheduledReminderAt = nil
        let signature = "\(reason)|\(scheduledAt?.timeIntervalSince1970 ?? clock.now().timeIntervalSince1970)"
        logOnce(
            event: AppAnalytics.Event.checkInCancelled,
            signature: signature,
            parameters: [AppAnalytics.Param.cancellationReason: reason]
        )
        return true
    }

    private func recordDeliveredIfPresent() async {
        let delivered = await notifications.delivered()
        guard let match = delivered.first(where: { $0.identifier == policy.notificationIdentifier }) else { return }
        store.lastReminderDeliveredAt = match.deliveredAt
    }

    private func logOnce(event: String, signature: String, parameters: [String: String]) {
        if store.analyticsSignatures[event] == signature { return }
        var signatures = store.analyticsSignatures
        signatures[event] = signature
        store.analyticsSignatures = signatures
        analytics.log(event, parameters: self.parameters(parameters))
    }

    private func parameters(_ extra: [String: String]) -> [String: String] {
        var payload = extra
        payload[AppAnalytics.Param.campaignVersion] = String(policy.campaignVersion)
        return payload
    }

    private func fireSignature(_ date: Date) -> String {
        String(date.timeIntervalSince1970)
    }

    private func perform(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = tail
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        tail = task
        await task.value
    }
}

protocol WidgetReminderActivityRecording: AnyObject {
    func recordAppOpen(at date: Date, remindersEnabled: Bool)
    func setRemindersEnabled(_ enabled: Bool)
    func restartAfterDataClear(at date: Date, remindersEnabled: Bool)
}

final class LiveWidgetReminderActivityRecorder: WidgetReminderActivityRecording {
    func recordAppOpen(at date: Date, remindersEnabled: Bool) {
        WidgetReminderActivityStore.recordAppOpen(at: date, remindersEnabled: remindersEnabled)
    }

    func setRemindersEnabled(_ enabled: Bool) {
        WidgetReminderActivityStore.setRemindersEnabled(enabled)
    }

    func restartAfterDataClear(at date: Date, remindersEnabled: Bool) {
        WidgetReminderActivityStore.restartAfterDataClear(at: date, remindersEnabled: remindersEnabled)
    }
}

final class NoOpWidgetReminderActivityRecorder: WidgetReminderActivityRecording {
    func recordAppOpen(at date: Date, remindersEnabled: Bool) {}
    func setRemindersEnabled(_ enabled: Bool) {}
    func restartAfterDataClear(at date: Date, remindersEnabled: Bool) {}
}