//
//  IncomeSetupJourney.swift
//  Xpnse
//

import Foundation

/// First production education journey: guides new users to configure regular income via Add Transaction.
struct IncomeSetupJourney: EducationOpportunityCampaign {
    static let campaignID = "income_setup"

    let identity = EducationCampaignIdentity(
        id: campaignID,
        name: "Income Setup",
        priority: 0
    )

    var completionValidator: any JourneyCompletionValidator {
        IncomeSetupCompletionValidator()
    }

    func evaluateFeatureEligibility(context: CampaignContext, state: CampaignState) -> CampaignDecision {
        if context.hasCriticalErrorThisSession {
            return .notEligible(.custom("criticalSessionError"))
        }
        if context.transactionCount > 0 {
            return .notEligible(.transactionsExist)
        }
        if context.hasRecurringIncome {
            return .notEligible(.recurringIncomeExists)
        }
        if context.hasConfiguredIncome {
            return .notEligible(.incomeExists)
        }
        return .eligible
    }

    func buildOpportunity(context: CampaignContext, state: CampaignState) -> EducationOpportunity {
        EducationOpportunity(
            campaignID: Self.campaignID,
            priority: identity.priority,
            sheetModel: Self.sheetModel,
            primaryAction: .openAddTransaction(.incomeSetupDefault),
            metadata: ["journey": Self.campaignID]
        )
    }

    static func outcomeForPrimaryAction() -> CampaignOutcome {
        .declined
    }

    static func outcomeForSecondaryButton() -> CampaignOutcome {
        .declined
    }

    static func outcomeForDismiss() -> CampaignOutcome {
        .declined
    }

    static func outcomeForSuccessfulIncomeSave() -> CampaignOutcome {
        .completed
    }

    static var defaultRegistry: EducationCampaignRegistry {
        EducationCampaignRegistry(campaigns: [IncomeSetupJourney()])
    }

    private static var sheetModel: EducationSheetModel {
        EducationSheetModel(
            id: "income_setup_sheet",
            title: L10n.tr("education.income.title"),
            description: L10n.tr("education.income.description"),
            primaryButton: EducationSheetButtonModel(
                id: "add_income",
                title: L10n.tr("education.income.primary")
            ),
            secondaryButton: EducationSheetButtonModel(
                id: "maybe_later",
                title: L10n.tr("education.common.maybe_later")
            )
        )
    }
}
