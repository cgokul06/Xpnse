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

    var followUpAfterSkipOf: String? { IncomeSetupJourney.campaignID }

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

    private static var sheetModel: EducationSheetModel {
        EducationSheetModel(
            id: "expense_setup_sheet",
            title: L10n.tr("education.expense.title"),
            description: L10n.tr("education.expense.description"),
            primaryButton: EducationSheetButtonModel(
                id: "add_expense",
                title: L10n.tr("education.expense.primary")
            ),
            secondaryButton: EducationSheetButtonModel(
                id: "maybe_later",
                title: L10n.tr("education.common.maybe_later")
            )
        )
    }
}
