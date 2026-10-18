//
//  EducationAnalytics.swift
//  Xpnse
//
//  Education funnel events. Campaign ids already match the spec `journey` values.
//

import Foundation

enum EducationAnalytics {
    static func presented(campaignID: String, trigger: String) {
        AppAnalytics.logEvent(AppAnalytics.Event.educationPresented, parameters: [
            AppAnalytics.Param.journey: campaignID,
            AppAnalytics.Param.trigger: trigger
        ])
    }

    static func actionSelected(campaignID: String, action: EducationJourneyAction) {
        AppAnalytics.logEvent(AppAnalytics.Event.educationActionSelected, parameters: [
            AppAnalytics.Param.journey: campaignID,
            AppAnalytics.Param.action: actionValue(action)
        ])
    }

    static func dismissed(campaignID: String, method: String) {
        AppAnalytics.logEvent(AppAnalytics.Event.educationDismissed, parameters: [
            AppAnalytics.Param.journey: campaignID,
            AppAnalytics.Param.dismissMethod: method
        ])
    }

    /// Called by `EducationEngine` only after an outcome actually changed journey state.
    static func outcomeApplied(_ outcome: CampaignOutcome, campaignID: String) {
        switch outcome {
        case .completed:
            AppAnalytics.logEvent(AppAnalytics.Event.educationCompleted, parameters: [
                AppAnalytics.Param.journey: campaignID
            ])
        case .actionFailed:
            if let reason = failureReason(for: campaignID) {
                AppAnalytics.logEvent(AppAnalytics.Event.educationActionFailed, parameters: [
                    AppAnalytics.Param.journey: campaignID,
                    AppAnalytics.Param.failureReason: reason.rawValue
                ])
            } else {
                AppAnalytics.logEvent(AppAnalytics.Event.educationActionCancelled, parameters: [
                    AppAnalytics.Param.journey: campaignID,
                    AppAnalytics.Param.reason: AppAnalytics.FailureReason.formClosed.rawValue
                ])
            }
        case .declined, .dismissed:
            break
        }
    }

    static func actionValue(_ action: EducationJourneyAction) -> String {
        switch action {
        case .openAddTransaction: return "open_add_transaction"
        case .openManageCategories: return "open_manage_categories"
        case .requestNotificationPermission: return "request_notification_permission"
        }
    }

    /// Only the reminder journey can genuinely fail (permission not granted). For the form-based
    /// journeys `actionFailed` means the user closed the form, which is a cancellation, not a failure.
    static func failureReason(for campaignID: String) -> AppAnalytics.FailureReason? {
        campaignID == RecurringReminderJourney.campaignID ? .permissionDenied : nil
    }
}
