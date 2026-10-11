//
//  RecurringReminderJourney.swift
//  Xpnse
//

import Foundation

/// Nudges the user to enable a reminder after saving their first recurring transaction without notify on.
struct RecurringReminderJourney: EducationOpportunityCampaign {
    static let campaignID = "recurring_reminder"

    let identity = EducationCampaignIdentity(
        id: campaignID,
        name: "Recurring Reminder",
        priority: 4
    )

    var completionValidator: any JourneyCompletionValidator {
        RecurringReminderCompletionValidator()
    }

    func evaluateFeatureEligibility(context: CampaignContext, state: CampaignState) -> CampaignDecision {
        if context.hasCriticalErrorThisSession {
            return .notEligible(.custom("criticalSessionError"))
        }
        if context.recurringTransactionCount == 0 {
            return .notEligible(.noRecurringTransaction)
        }
        if context.hasEnabledRecurringReminder {
            return .notEligible(.reminderAlreadyEnabled)
        }
        switch context.notificationAuthorizationStatus {
        case .notDetermined:
            break
        case .authorized, .provisional, .ephemeral:
            return .notEligible(.notificationAlreadyGranted)
        case .denied:
            return .notEligible(.notificationPermissionDenied)
        case .unknown:
            return .notEligible(.custom("notificationStatusUnknown"))
        }
        return .eligible
    }

    func buildOpportunity(context: CampaignContext, state: CampaignState) -> EducationOpportunity {
        EducationOpportunity(
            campaignID: Self.campaignID,
            priority: identity.priority,
            sheetModel: Self.sheetModel,
            primaryAction: .requestNotificationPermission,
            metadata: ["journey": Self.campaignID]
        )
    }

    static func outcomeForSecondaryButton() -> CampaignOutcome {
        .declined
    }

    static func outcomeForDismiss() -> CampaignOutcome {
        .dismissed
    }

    static func outcomeForSuccessfulPermission() -> CampaignOutcome {
        .completed
    }

    static var defaultRegistry: EducationCampaignRegistry {
        EducationCampaignRegistry(campaigns: [
            IncomeSetupJourney(),
            RecurringReminderJourney(),
            ExpenseSetupJourney()
        ])
    }

    private static let sheetModel = EducationSheetModel(
        id: "recurring_reminder_sheet",
        icon: .sfSymbol("bell.badge.fill"),
        title: "Get a reminder before it's due",
        description: "We'll remind you before this transaction happens next time, so you can keep your funds ready.",
        primaryButton: EducationSheetButtonModel(
            id: "enable_reminder",
            title: "Yes, remind me"
        ),
        secondaryButton: EducationSheetButtonModel(
            id: "not_now",
            title: "Not Now"
        )
    )
}
