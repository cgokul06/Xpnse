//
//  CampaignContext.swift
//  Xpnse
//

import Foundation

/// UIKit-free notification authorization snapshot for campaign evaluation.
enum EducationNotificationAuthorizationStatus: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

/// Read-only inputs for campaign eligibility evaluation. Built by a future coordinator.
struct CampaignContext: Equatable, Sendable {
    var daysSinceInstall: Int
    var launchCount: Int
    var activeDays: Int
    var transactionCount: Int
    var incomeCount: Int
    var hasRecurringIncome: Bool
    var hasConfiguredIncome: Bool
    var expenseCount: Int
    var recurringTransactionCount: Int
    var hasEnabledRecurringReminder: Bool
    var customCategoryCount: Int
    var receiptScanCount: Int
    var notificationAuthorizationStatus: EducationNotificationAuthorizationStatus
    var isWidgetInstalled: Bool
    var appVersion: String
    var hasCriticalErrorThisSession: Bool
    var lastEducationDate: Date?
    var evaluationDate: Date

    init(
        daysSinceInstall: Int = 0,
        launchCount: Int = 0,
        activeDays: Int = 0,
        transactionCount: Int = 0,
        incomeCount: Int = 0,
        hasRecurringIncome: Bool = false,
        hasConfiguredIncome: Bool = false,
        expenseCount: Int = 0,
        recurringTransactionCount: Int = 0,
        hasEnabledRecurringReminder: Bool = false,
        customCategoryCount: Int = 0,
        receiptScanCount: Int = 0,
        notificationAuthorizationStatus: EducationNotificationAuthorizationStatus = .unknown,
        isWidgetInstalled: Bool = false,
        appVersion: String = "",
        hasCriticalErrorThisSession: Bool = false,
        lastEducationDate: Date? = nil,
        evaluationDate: Date = Date()
    ) {
        self.daysSinceInstall = daysSinceInstall
        self.launchCount = launchCount
        self.activeDays = activeDays
        self.transactionCount = transactionCount
        self.incomeCount = incomeCount
        self.hasRecurringIncome = hasRecurringIncome
        self.hasConfiguredIncome = hasConfiguredIncome
        self.expenseCount = expenseCount
        self.recurringTransactionCount = recurringTransactionCount
        self.hasEnabledRecurringReminder = hasEnabledRecurringReminder
        self.customCategoryCount = customCategoryCount
        self.receiptScanCount = receiptScanCount
        self.notificationAuthorizationStatus = notificationAuthorizationStatus
        self.isWidgetInstalled = isWidgetInstalled
        self.appVersion = appVersion
        self.hasCriticalErrorThisSession = hasCriticalErrorThisSession
        self.lastEducationDate = lastEducationDate
        self.evaluationDate = evaluationDate
    }
}
