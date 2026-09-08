//
//  EducationOpportunityCampaign.swift
//  Xpnse
//

import Foundation

/// Campaigns that produce a presentation opportunity when eligible.
protocol EducationOpportunityCampaign: EducationCampaign {
    func buildOpportunity(context: CampaignContext, state: CampaignState) -> EducationOpportunity
}

extension EducationOpportunityCampaign {
    func makeOpportunity(
        context: CampaignContext,
        state: CampaignState,
        allStates: [CampaignState]
    ) -> EducationOpportunity? {
        guard evaluate(context: context, state: state, allStates: allStates) == .eligible else { return nil }
        return buildOpportunity(context: context, state: state)
    }
}
