//
//  AddTransactionPrefill.swift
//  Xpnse
//

import Foundation

/// View-layer prefill for opening Add Transaction with initial field values.
struct AddTransactionPrefill: Equatable, Hashable, Sendable {
    let transactionType: TransactionType
    let isRecurring: Bool
    let focusCategoryPicker: Bool
    let enableAddCategoryShortcut: Bool

    init(
        transactionType: TransactionType,
        isRecurring: Bool,
        focusCategoryPicker: Bool = false,
        enableAddCategoryShortcut: Bool = false
    ) {
        self.transactionType = transactionType
        self.isRecurring = isRecurring
        self.focusCategoryPicker = focusCategoryPicker
        self.enableAddCategoryShortcut = enableAddCategoryShortcut
    }

    init(launchConfiguration: AddTransactionLaunchConfiguration) {
        self.transactionType = launchConfiguration.transactionType
        self.isRecurring = launchConfiguration.isRecurringEnabled
        self.focusCategoryPicker = launchConfiguration.focusCategoryPicker
        self.enableAddCategoryShortcut = launchConfiguration.enableAddCategoryShortcut
    }
}

extension AddTransactionLaunchConfiguration {
    var addTransactionPrefill: AddTransactionPrefill {
        AddTransactionPrefill(launchConfiguration: self)
    }
}
