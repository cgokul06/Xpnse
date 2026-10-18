//
//  RecurringReminderJourney.swift
//  Xpnse
//

import Foundation

/// Nudges the user to enable a reminder when saving an expense or savings recurring transaction without notify on.
/// Started by Add Transaction before the save; the engine never publishes it on its own.
struct RecurringReminderJourney: EducationOpportunityCampaign {
    static let campaignID = "recurring_reminder"

    let identity = EducationCampaignIdentity(
        id: campaignID,
        name: "Recurring Reminder",
        priority: 4
    )

    var presentsAutomatically: Bool { false }

    var completionValidator: any JourneyCompletionValidator {
        RecurringReminderCompletionValidator()
    }

    func evaluateFeatureEligibility(context: CampaignContext, state: CampaignState) -> CampaignDecision {
        if context.hasCriticalErrorThisSession {
            return .notEligible(.custom("criticalSessionError"))
        }
        if context.reminderEligibleRecurringCount == 0 {
            return .notEligible(.noRecurringTransaction)
        }
        if context.hasEnabledRecurringReminder {
            return .notEligible(.reminderAlreadyEnabled)
        }
        switch context.notificationAuthorizationStatus {
        case .notDetermined, .provisional:
            break
        case .authorized, .ephemeral:
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

    private static var sheetModel: EducationSheetModel {
        EducationSheetModel(
            id: "recurring_reminder_sheet",
            icon: .sfSymbol("bell.badge.fill"),
            title: L10n.tr("education.reminder.title"),
            description: L10n.tr("education.reminder.description"),
            primaryButton: EducationSheetButtonModel(
                id: "enable_reminder",
                title: L10n.tr("education.reminder.primary")
            ),
            secondaryButton: EducationSheetButtonModel(
                id: "not_now",
                title: L10n.tr("education.reminder.secondary")
            )
        )
    }
}
