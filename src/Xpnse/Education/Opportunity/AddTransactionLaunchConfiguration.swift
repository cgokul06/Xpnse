//
//  AddTransactionLaunchConfiguration.swift
//  Xpnse
//

import Foundation

/// UI-independent configuration for opening the existing Add Transaction flow.
struct AddTransactionLaunchConfiguration: Equatable, Sendable {
    let transactionType: TransactionType
    let isRecurringEnabled: Bool
    let focusCategoryPicker: Bool
    let enableAddCategoryShortcut: Bool

    init(
        transactionType: TransactionType,
        isRecurringEnabled: Bool,
        focusCategoryPicker: Bool = false,
        enableAddCategoryShortcut: Bool = false
    ) {
        self.transactionType = transactionType
        self.isRecurringEnabled = isRecurringEnabled
        self.focusCategoryPicker = focusCategoryPicker
        self.enableAddCategoryShortcut = enableAddCategoryShortcut
    }

    static let incomeSetupDefault = AddTransactionLaunchConfiguration(
        transactionType: .income,
        isRecurringEnabled: true
    )

    static let customCategoryDiscovery = AddTransactionLaunchConfiguration(
        transactionType: .expense,
        isRecurringEnabled: false,
        focusCategoryPicker: true,
        enableAddCategoryShortcut: true
    )
}
