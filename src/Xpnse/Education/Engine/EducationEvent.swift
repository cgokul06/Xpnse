//
//  EducationEvent.swift
//  Xpnse
//

import Foundation

/// Feature-agnostic user or application events consumed by the education engine.
enum EducationEvent: Equatable, Sendable {
    case appLaunched
    case appBecameActive
    case transactionAdded
    case incomeConfigured
    case categoryCreated
    case recurringTransactionCreated
    case reminderEnabled
    case notificationPermissionGranted
    case widgetAdded
    case journeyOutcomeApplied(campaignID: String)
}
