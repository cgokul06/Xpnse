//
//  CompletionValidationContext.swift
//  Xpnse
//

import Foundation

/// Application state snapshot used to verify a journey's objective has been achieved.
struct CompletionValidationContext: Equatable, Sendable {
    var hasConfiguredIncome: Bool
    var hasRecurringIncome: Bool
    var customCategoryCount: Int
    var recurringExpenseCount: Int
    var isReminderEnabled: Bool
    var notificationAuthorizationStatus: EducationNotificationAuthorizationStatus
    var isWidgetInstalled: Bool
    var receiptScanCount: Int
    var hasGeneratedInsights: Bool

    init(
        hasConfiguredIncome: Bool = false,
        hasRecurringIncome: Bool = false,
        customCategoryCount: Int = 0,
        recurringExpenseCount: Int = 0,
        isReminderEnabled: Bool = false,
        notificationAuthorizationStatus: EducationNotificationAuthorizationStatus = .unknown,
        isWidgetInstalled: Bool = false,
        receiptScanCount: Int = 0,
        hasGeneratedInsights: Bool = false
    ) {
        self.hasConfiguredIncome = hasConfiguredIncome
        self.hasRecurringIncome = hasRecurringIncome
        self.customCategoryCount = customCategoryCount
        self.recurringExpenseCount = recurringExpenseCount
        self.isReminderEnabled = isReminderEnabled
        self.notificationAuthorizationStatus = notificationAuthorizationStatus
        self.isWidgetInstalled = isWidgetInstalled
        self.receiptScanCount = receiptScanCount
        self.hasGeneratedInsights = hasGeneratedInsights
    }

    static func from(campaignContext: CampaignContext) -> CompletionValidationContext {
        CompletionValidationContext(
            hasConfiguredIncome: campaignContext.hasConfiguredIncome,
            hasRecurringIncome: campaignContext.hasRecurringIncome,
            customCategoryCount: campaignContext.customCategoryCount,
            notificationAuthorizationStatus: campaignContext.notificationAuthorizationStatus,
            isWidgetInstalled: campaignContext.isWidgetInstalled,
            receiptScanCount: campaignContext.receiptScanCount
        )
    }
}
