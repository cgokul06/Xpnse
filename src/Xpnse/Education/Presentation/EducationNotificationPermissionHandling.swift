//
//  EducationNotificationPermissionHandling.swift
//  Xpnse
//

import Foundation

/// Requests OS notification permission when the user accepts the reminder prompt.
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
        return RecurringReminderJourney.outcomeForSuccessfulPermission()
    }
}
