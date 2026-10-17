//
//  AppEducationEvaluationContextProviderTests.swift
//  XpnseTests
//

import XCTest
@testable import Xpnse

final class AppEducationEvaluationContextProviderTests: XCTestCase {
    private let inr = CurrencyOption(id: 1, code: "INR", name: "Indian Rupee", symbol: "₹")

    func testEmptyDataIsIncomeEligible() {
        let context = AppEducationEvaluationContextProvider.makeCampaignContext(
            transactions: [],
            recurring: [],
            categories: []
        )

        XCTAssertEqual(context.transactionCount, 0)
        XCTAssertEqual(context.expenseCount, 0)
        XCTAssertFalse(context.hasConfiguredIncome)
        XCTAssertFalse(context.hasRecurringIncome)
        XCTAssertEqual(context.customCategoryCount, 0)
    }

    func testExpenseTransactionIncrementsCountWithoutConfiguredIncome() {
        let context = AppEducationEvaluationContextProvider.makeCampaignContext(
            transactions: [transaction(type: .expense)],
            recurring: [],
            categories: []
        )

        XCTAssertEqual(context.transactionCount, 1)
        XCTAssertEqual(context.incomeCount, 0)
        XCTAssertEqual(context.expenseCount, 1)
        XCTAssertFalse(context.hasConfiguredIncome)
        XCTAssertFalse(context.hasRecurringIncome)
    }

    func testIncomeTransactionSetsConfiguredIncome() {
        let context = AppEducationEvaluationContextProvider.makeCampaignContext(
            transactions: [transaction(type: .income)],
            recurring: [],
            categories: []
        )

        XCTAssertTrue(context.hasConfiguredIncome)
        XCTAssertEqual(context.incomeCount, 1)
        XCTAssertEqual(context.expenseCount, 0)
        XCTAssertEqual(context.transactionCount, 1)
        XCTAssertFalse(context.hasRecurringIncome)
    }

    func testActiveRecurringIncomeSetsFlags() {
        let context = AppEducationEvaluationContextProvider.makeCampaignContext(
            transactions: [],
            recurring: [recurring(type: .income, state: .active)],
            categories: []
        )

        XCTAssertTrue(context.hasRecurringIncome)
        XCTAssertTrue(context.hasConfiguredIncome)
        XCTAssertEqual(context.recurringTransactionCount, 1)
        XCTAssertEqual(context.reminderEligibleRecurringCount, 0)
        XCTAssertFalse(context.hasEnabledRecurringReminder)
    }

    func testRecurringReminderFlagAndNotificationStatus() {
        var withReminder = recurring(type: .expense, state: .active)
        withReminder.notificationReminderEnabled = true
        let context = AppEducationEvaluationContextProvider.makeCampaignContext(
            transactions: [],
            recurring: [withReminder],
            categories: [],
            notificationAuthorizationStatus: .notDetermined
        )

        XCTAssertEqual(context.recurringTransactionCount, 1)
        XCTAssertEqual(context.reminderEligibleRecurringCount, 1)
        XCTAssertTrue(context.hasEnabledRecurringReminder)
        XCTAssertEqual(context.notificationAuthorizationStatus, .notDetermined)
    }

    func testSavingsRecurringIsReminderEligibleAndIncomeIsNot() {
        var incomeWithReminder = recurring(type: .income, state: .active)
        incomeWithReminder.notificationReminderEnabled = true
        let savings = recurring(type: .savings, state: .active)
        let context = AppEducationEvaluationContextProvider.makeCampaignContext(
            transactions: [],
            recurring: [incomeWithReminder, savings],
            categories: []
        )

        XCTAssertEqual(context.recurringTransactionCount, 2)
        XCTAssertEqual(context.reminderEligibleRecurringCount, 1)
        XCTAssertFalse(context.hasEnabledRecurringReminder)
    }

    func testPausedRecurringIncomeIsIgnored() {
        let context = AppEducationEvaluationContextProvider.makeCampaignContext(
            transactions: [],
            recurring: [recurring(type: .income, state: .paused)],
            categories: []
        )

        XCTAssertFalse(context.hasRecurringIncome)
        XCTAssertFalse(context.hasConfiguredIncome)
    }

    func testCustomCategoryCountIgnoresBuiltInAndDeleted() {
        let builtIn = CategoryDefinition(
            id: "food",
            name: "Food",
            symbolName: "fork.knife",
            colorHex: "#000000",
            transactionType: .expense,
            isBuiltIn: true
        )
        var deleted = CategoryDefinition(
            id: "pets",
            name: "Pets",
            symbolName: "pawprint",
            colorHex: "#111111",
            transactionType: .expense,
            isBuiltIn: false
        )
        deleted.isDeleted = true
        let custom = CategoryDefinition(
            id: "kids",
            name: "Kids",
            symbolName: "figure.and.child.holdinghands",
            colorHex: "#222222",
            transactionType: .expense,
            isBuiltIn: false
        )

        let context = AppEducationEvaluationContextProvider.makeCampaignContext(
            transactions: [],
            recurring: [],
            categories: [builtIn, deleted, custom]
        )

        XCTAssertEqual(context.customCategoryCount, 1)
    }

    private func transaction(type: TransactionType) -> Transaction {
        Transaction(
            id: UUID().uuidString,
            type: type,
            categoryId: "other",
            amount: 100,
            title: "Test",
            currency: inr
        )
    }

    private func recurring(type: TransactionType, state: RecurringTransactionState) -> RecurringTransaction {
        RecurringTransaction(
            title: "Recurring",
            type: type.rawValue,
            amount: 100,
            startDate: Date(),
            recurrence: .daily,
            state: state
        )
    }
}
