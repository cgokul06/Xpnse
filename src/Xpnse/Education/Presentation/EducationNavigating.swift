//
//  EducationNavigating.swift
//  Xpnse
//

import Foundation

/// Navigation performed when an education primary action runs.
@MainActor
protocol EducationNavigating: AnyObject {
    func openAddTransaction(_ prefill: AddTransactionPrefill)
    func openManageCategories()
}

/// Engine surface used by presentation. Tests can supply a fake without `EducationEngine` deinit issues.
protocol EducationPresentingEngine: AnyObject {
    var currentOpportunity: EducationOpportunity? { get }
    var isPresentationPending: Bool { get }
    var runtimeState: EducationRuntimeState { get }
    func applyOutcome(_ outcome: CampaignOutcome, campaignID: String)
    func acceptPrimaryAction(campaignID: String)
    func track(_ event: EducationEvent)
    func beginHostedPresentation(
        campaignID: String,
        adjustingContext: (inout CampaignContext) -> Void
    ) -> EducationOpportunity?
}

extension EducationEngine: EducationPresentingEngine {}
