//
//  AppEducationEvaluationContextProvider.swift
//  Xpnse
//

import Foundation
import UserNotifications

/// Live evaluation snapshot built from local transactions, recurring rules, and categories.
final class AppEducationEvaluationContextProvider: EducationEvaluationContextProviding, @unchecked Sendable {
    static let shared = AppEducationEvaluationContextProvider()

    private let lock = NSLock()
    private var cachedContext = CampaignContext()
    private let transactionRepository: TransactionRepository
    private let recurringRepository: RecurringRepository
    private let loadCategories: @MainActor () -> [CategoryDefinition]
    private let notificationAuthorizationStatus: () async -> EducationNotificationAuthorizationStatus

    init(
        transactionRepository: TransactionRepository = SwiftDataTransactionRepository.shared,
        recurringRepository: RecurringRepository = SwiftDataRecurringRepository.shared,
        loadCategories: @escaping @MainActor () -> [CategoryDefinition] = {
            CategoryStore.shared.categories
        },
        notificationAuthorizationStatus: @escaping () async -> EducationNotificationAuthorizationStatus = {
            await EducationNotificationAuthorizationStatus.loadCurrent()
        }
    ) {
        self.transactionRepository = transactionRepository
        self.recurringRepository = recurringRepository
        self.loadCategories = loadCategories
        self.notificationAuthorizationStatus = notificationAuthorizationStatus
    }

    func refresh() async {
        let transactions = (try? await transactionRepository.fetchAll()) ?? []
        let recurring = (try? await recurringRepository.fetchAll()) ?? []
        let categories = await MainActor.run { loadCategories() }
        let notificationStatus = await notificationAuthorizationStatus()
        let context = Self.makeCampaignContext(
            transactions: transactions,
            recurring: recurring,
            categories: categories,
            notificationAuthorizationStatus: notificationStatus
        )
        lock.lock()
        cachedContext = context
        lock.unlock()
    }

    func snapshot(for event: EducationEvent, at date: Date) -> EducationEvaluationSnapshot {
        lock.lock()
        let cached = cachedContext
        lock.unlock()
        return EducationEvaluationSnapshot(campaignContext: cached, at: date)
    }

    static func makeCampaignContext(
        transactions: [Transaction],
        recurring: [RecurringTransaction],
        categories: [CategoryDefinition],
        notificationAuthorizationStatus: EducationNotificationAuthorizationStatus = .unknown,
        evaluationDate: Date = Date()
    ) -> CampaignContext {
        let incomeTransactions = transactions.filter { $0.type == .income }
        let expenseTransactions = transactions.filter { $0.type == .expense }
        let activeRecurring = recurring.filter { $0.state == .active }
        let hasRecurringIncome = activeRecurring.contains {
            $0.type == TransactionType.income.rawValue
        }
        let reminderEligibleRecurring = activeRecurring.filter {
            TransactionType(rawValue: $0.type)?.isEducationReminderEligible == true
        }
        let hasEnabledRecurringReminder = reminderEligibleRecurring.contains {
            $0.notificationReminderEnabled
        }
        let customCategoryCount = categories.filter { !$0.isBuiltIn && !$0.isDeleted }.count
        return CampaignContext(
            transactionCount: transactions.count,
            incomeCount: incomeTransactions.count,
            hasRecurringIncome: hasRecurringIncome,
            hasConfiguredIncome: !incomeTransactions.isEmpty || hasRecurringIncome,
            expenseCount: expenseTransactions.count,
            recurringTransactionCount: activeRecurring.count,
            reminderEligibleRecurringCount: reminderEligibleRecurring.count,
            hasEnabledRecurringReminder: hasEnabledRecurringReminder,
            customCategoryCount: customCategoryCount,
            notificationAuthorizationStatus: notificationAuthorizationStatus,
            evaluationDate: evaluationDate
        )
    }
}

extension EducationNotificationAuthorizationStatus {
    static func loadCurrent() async -> EducationNotificationAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: .from(settings.authorizationStatus))
            }
        }
    }

    static func from(_ status: UNAuthorizationStatus) -> EducationNotificationAuthorizationStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .ephemeral
        @unknown default: return .unknown
        }
    }
}
