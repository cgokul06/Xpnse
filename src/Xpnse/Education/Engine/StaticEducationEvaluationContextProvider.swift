//
//  StaticEducationEvaluationContextProvider.swift
//  Xpnse
//

import Foundation

/// Fixed evaluation snapshot for tests and default shared engine wiring.
struct StaticEducationEvaluationContextProvider: EducationEvaluationContextProviding {
    private let campaignContext: CampaignContext
    private let validationContext: CompletionValidationContext

    init(
        campaignContext: CampaignContext = CampaignContext(),
        validationContext: CompletionValidationContext? = nil
    ) {
        self.campaignContext = campaignContext
        self.validationContext = validationContext
            ?? CompletionValidationContext.from(campaignContext: campaignContext)
    }

    func snapshot(for event: EducationEvent, at date: Date) -> EducationEvaluationSnapshot {
        EducationEvaluationSnapshot(campaignContext: campaignContext, at: date)
            .replacingValidationContext(validationContext)
    }
}

private extension EducationEvaluationSnapshot {
    func replacingValidationContext(_ validationContext: CompletionValidationContext) -> EducationEvaluationSnapshot {
        EducationEvaluationSnapshot(
            campaignContext: campaignContext,
            validationContext: validationContext
        )
    }
}
