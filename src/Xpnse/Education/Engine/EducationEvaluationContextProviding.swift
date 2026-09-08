//
//  EducationEvaluationContextProviding.swift
//  Xpnse
//

import Foundation

/// Application state snapshot used during journey evaluation and completion validation.
struct EducationEvaluationSnapshot: Equatable, Sendable {
    let campaignContext: CampaignContext
    let validationContext: CompletionValidationContext

    init(
        campaignContext: CampaignContext,
        validationContext: CompletionValidationContext
    ) {
        self.campaignContext = campaignContext
        self.validationContext = validationContext
    }

    init(
        campaignContext: CampaignContext,
        at date: Date = Date()
    ) {
        var context = campaignContext
        context.evaluationDate = date
        self.campaignContext = context
        self.validationContext = CompletionValidationContext.from(campaignContext: context)
    }
}

/// Supplies evaluation snapshots without coupling the engine to app data sources.
protocol EducationEvaluationContextProviding: Sendable {
    func snapshot(for event: EducationEvent, at date: Date) -> EducationEvaluationSnapshot
}
