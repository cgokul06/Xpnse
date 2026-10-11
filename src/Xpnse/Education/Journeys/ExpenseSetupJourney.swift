//
//  ExpenseSetupJourney.swift
//  Xpnse
//

import Foundation

/// Second production education journey: guides users to log their first expense after income setup.
struct ExpenseSetupJourney: EducationOpportunityCampaign {
    static let campaignID = "expense_setup"

    let identity = EducationCampaignIdentity(
        id: campaignID,
        name: "Expense Setup",
        priority: 5
    )

    var prerequisites: [JourneyPrerequisite] {
        [.completedOrDeclined(IncomeSetupJourney.campaignID)]
    }

    var completionValidator: any JourneyCompletionValidator {
        ExpenseSetupCompletionValidator()
    }

    func evaluateFeatureEligibility(context: CampaignContext, state: CampaignState) -> CampaignDecision {
        if context.hasCriticalErrorThisSession {
            return .notEligible(.custom("criticalSessionError"))
        }
        if context.expenseCount > 0 {
            return .notEligible(.expenseExists)
        }
        return .eligible
    }

    func buildOpportunity(context: CampaignContext, state: CampaignState) -> EducationOpportunity {
        EducationOpportunity(
            campaignID: Self.campaignID,
            priority: identity.priority,
            sheetModel: Self.sheetModel,
            primaryAction: .openAddTransaction(.expenseSetupDefault),
            metadata: ["journey": Self.campaignID]
        )
    }

    static func outcomeForSecondaryButton() -> CampaignOutcome {
        .declined
    }

    static func outcomeForDismiss() -> CampaignOutcome {
        .dismissed
    }

    static func outcomeForSuccessfulExpenseSave() -> CampaignOutcome {
        .completed
    }

    static var defaultRegistry: EducationCampaignRegistry {
        EducationCampaignRegistry(campaigns: [IncomeSetupJourney(), ExpenseSetupJourney()])
    }

    private static let sheetModel = EducationSheetModel(
        id: "expense_setup_sheet",
        title: "Track your first expense",
        description: "Adding a spend helps SnapLedger understand where your money goes and personalize your dashboard.",
        primaryButton: EducationSheetButtonModel(
            id: "add_expense",
            title: "Add Expense"
        ),
        secondaryButton: EducationSheetButtonModel(
            id: "maybe_later",
            title: "Maybe Later"
        )
    )
}
