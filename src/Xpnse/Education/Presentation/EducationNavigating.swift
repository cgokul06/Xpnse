//
//  EducationNavigating.swift
//  Xpnse
//

import Foundation

/// Navigation performed when an education primary action runs.
@MainActor
protocol EducationNavigating: AnyObject {
    func openAddTransaction(_ prefill: AddTransactionPrefill)
}

/// Engine surface used by presentation. Tests can supply a fake without `EducationEngine` deinit issues.
protocol EducationPresentingEngine: AnyObject {
    var currentOpportunity: EducationOpportunity? { get }
    func applyOutcome(_ outcome: CampaignOutcome, campaignID: String)
    func clearCurrentOpportunity()
    func evaluateJourneys()
}

extension EducationEngine: EducationPresentingEngine {}
