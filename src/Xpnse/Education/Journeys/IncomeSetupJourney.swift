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
        .dismissed
    }

    static func outcomeForSuccessfulIncomeSave() -> CampaignOutcome {
        .completed
    }

    static var defaultRegistry: EducationCampaignRegistry {
        EducationCampaignRegistry(campaigns: [IncomeSetupJourney()])
    }

    private static let sheetModel = EducationSheetModel(
        id: "income_setup_sheet",
        title: "Welcome to SnapLedger 👋",
        description: "Let's get your finances started. Adding your regular income gives SnapLedger a better understanding of your finances and helps personalize your dashboard.",
        primaryButton: EducationSheetButtonModel(
            id: "add_income",
            title: "Add My Income"
        ),
        secondaryButton: EducationSheetButtonModel(
            id: "maybe_later",
            title: "Maybe Later"
        )
    )
}
