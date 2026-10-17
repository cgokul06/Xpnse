//
//  CustomCategoryJourney.swift
//  Xpnse
//

import Foundation

/// Education journey that introduces custom categories after basic engagement.
struct CustomCategoryJourney: EducationOpportunityCampaign {
    static let campaignID = "custom_category"
    static let minimumTransactionCount = 3

    let identity = EducationCampaignIdentity(
        id: campaignID,
        name: "Custom Category",
        priority: 10
    )

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
            primaryAction: .openManageCategories,
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
        EducationCampaignRegistry(campaigns: [
            IncomeSetupJourney(),
            RecurringReminderJourney(),
            ExpenseSetupJourney(),
            CustomCategoryJourney()
        ])
    }

    private static var sheetModel: EducationSheetModel {
        EducationSheetModel(
            id: "custom_category_sheet",
            title: L10n.tr("education.category.title"),
            description: L10n.tr("education.category.description"),
            primaryButton: EducationSheetButtonModel(
                id: "create_category",
                title: L10n.tr("education.category.primary")
            ),
            secondaryButton: EducationSheetButtonModel(
                id: "maybe_later",
                title: L10n.tr("education.common.maybe_later")
            )
        )
    }
}
