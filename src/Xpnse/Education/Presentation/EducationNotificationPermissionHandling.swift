//
//  EducationNotificationPermissionHandling.swift
//  Xpnse
//

import Foundation

/// Requests OS notification permission and enables a default recurring reminder when the user accepts.
protocol EducationNotificationPermissionHandling: AnyObject {
    func requestAuthorizationAndEnableReminder() async -> CampaignOutcome
}

@MainActor
final class LiveEducationNotificationPermissionHandler: EducationNotificationPermissionHandling {
    func requestAuthorizationAndEnableReminder() async -> CampaignOutcome {
        let allowed = await RecurringReminderScheduler.shared.validateWhenTurningRemindMeOn()
        guard allowed else {
            return RecurringReminderJourney.outcomeForSecondaryButton()
        }
        let enabled = await RecurringReminderScheduler.shared.enableDefaultReminderOnFirstUnnotifiedRecurring()
        guard enabled else {
            return .actionFailed
        }
        await AppEducationEvaluationContextProvider.shared.refresh()
        return RecurringReminderJourney.outcomeForSuccessfulPermission()
    }
}
