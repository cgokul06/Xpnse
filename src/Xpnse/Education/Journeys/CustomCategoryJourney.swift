//
//  CustomCategoryJourney.swift
//  Xpnse
//

import Foundation

/// Education journey that introduces custom categories after basic engagement.
struct CustomCategoryJourney: EducationOpportunityCampaign {
    static let campaignID = "custom_category"
    static let minimumTransactionCount = 5

    let identity = EducationCampaignIdentity(
        id: campaignID,
        name: "Custom Category",
        priority: 10
    )

    var prerequisites: [JourneyPrerequisite] {
        [.completed(IncomeSetupJourney.campaignID)]
    }

    var completionValidator: any JourneyCompletionValidator {
        CustomCategoryCompletionValidator()
    }

    func evaluateFeatureEligibility(context: CampaignContext, state: CampaignState) -> CampaignDecision {
        if context.hasCriticalErrorThisSession {
            return .notEligible(.custom("criticalSessionError"))
        }
        if context.transactionCount < Self.minimumTransactionCount {
            return .notEligible(.tooFewTransactions)
        }
        if context.customCategoryCount > 0 {
            return .notEligible(.customCategoryExists)
        }
        return .eligible
    }

    func buildOpportunity(context: CampaignContext, state: CampaignState) -> EducationOpportunity {
        EducationOpportunity(
            campaignID: Self.campaignID,
            priority: identity.priority,
            sheetModel: Self.sheetModel,
            primaryAction: .openAddTransaction(.customCategoryDiscovery),
            metadata: ["journey": Self.campaignID]
        )
    }

    static func outcomeForSecondaryButton() -> CampaignOutcome {
        .declined
    }

    static func outcomeForDismiss() -> CampaignOutcome {
        .dismissed
    }

    static func outcomeForSuccessfulCustomCategoryCreation() -> CampaignOutcome {
        .completed
    }

    static var defaultRegistry: EducationCampaignRegistry {
        EducationCampaignRegistry(campaigns: [IncomeSetupJourney(), CustomCategoryJourney()])
    }

    private static let sheetModel = EducationSheetModel(
        id: "custom_category_sheet",
        title: "Organize your spending your way",
        description: "Create your own categories to match how you manage your finances. Whether it's Kids, Travel, Pets or Investments, SnapLedger adapts to you.",
        primaryButton: EducationSheetButtonModel(
            id: "create_category",
            title: "Create Category"
        ),
        secondaryButton: EducationSheetButtonModel(
            id: "maybe_later",
            title: "Maybe Later"
        )
    )
}
