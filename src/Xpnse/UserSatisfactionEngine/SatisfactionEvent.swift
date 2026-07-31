//
//  SatisfactionEvent.swift
//  Xpnse
//

import Foundation

enum SatisfactionEvent: Equatable {
    case appLaunched
    case appBecameActive
    case appEnteredBackground
    case transactionAdded
    case receiptScanned
    case insightsGenerated
    case criticalErrorOccurred
    case reviewPromptDismissed
    case feedbackSubmitted
    case appStoreReviewOpened
}

enum BusyWorkReason: Hashable {
    case addOrEditTransaction
    case deleteTransaction
    case billScanner
    case importExport
    case manageCategories
    case manageRecurring
    case currencySetup
    case settingsCriticalFlow
}
