//
//  EducationJourneyAction.swift
//  Xpnse
//

import Foundation

/// UI-independent action requested by an education journey. The presentation layer performs navigation.
enum EducationJourneyAction: Equatable, Sendable {
    case openAddTransaction(AddTransactionLaunchConfiguration)
    case openManageCategories
}
