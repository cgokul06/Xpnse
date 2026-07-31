//
//  SatisfactionAnalytics.swift
//  Xpnse
//

import Foundation

enum SatisfactionAnalyticsEvent: String {
    case eligibilityPassed = "review_eligibility_passed"
    case eligibilityFailed = "review_eligibility_failed"
    case triggerTransactionMilestone = "review_trigger_txn_milestone"
    case triggerReceiptMilestone = "review_trigger_receipt_milestone"
    case triggerInsights = "review_trigger_insights"
    case triggerSevenDayStreak = "review_trigger_seven_day_streak"
    case feedbackFlowPresented = "review_feedback_flow_presented"
    case positiveSelected = "review_positive_selected"
    case negativeSelected = "review_negative_selected"
    case feedbackSubmitted = "review_feedback_submitted"
    case feedbackCancelled = "review_feedback_cancelled"
    case reviewDismissed = "review_dismissed"
    case appStoreOpened = "review_app_store_opened"
}

protocol SatisfactionAnalytics {
    func log(_ event: SatisfactionAnalyticsEvent, parameters: [String: String])
}

struct NoOpSatisfactionAnalytics: SatisfactionAnalytics {
    func log(_ event: SatisfactionAnalyticsEvent, parameters: [String: String]) {}
}

struct AppAnalyticsSatisfactionAdapter: SatisfactionAnalytics {
    func log(_ event: SatisfactionAnalyticsEvent, parameters: [String: String]) {
        AppAnalytics.logEvent(event.rawValue, parameters: parameters)
    }
}

final class RecordingSatisfactionAnalytics: SatisfactionAnalytics {
    private(set) var events: [(SatisfactionAnalyticsEvent, [String: String])] = []

    func log(_ event: SatisfactionAnalyticsEvent, parameters: [String: String]) {
        events.append((event, parameters))
    }

    func reset() {
        events.removeAll()
    }
}
