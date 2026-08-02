//
//  AppAnalytics.swift
//  Xpnse
//
//  Privacy-safe usability analytics. Never log amounts, merchants,
//  descriptions, category names, emails, or other personal/financial content.
//

import Foundation
import FirebaseAnalytics

enum AppAnalytics {
    /// Allowed parameter keys only — keep values non-PII (e.g. "success", "fail", feature ids).
    enum Param {
        static let source = "source"
        static let result = "result"
        static let featureKey = "feature_key"
        static let enabled = "enabled"
        static let button = "button"
    }

    enum Screen {
        static let home = "home"
        static let insights = "insights"
        static let addTransaction = "add_transaction"
        static let editTransaction = "edit_transaction"
        static let manageCategories = "manage_categories"
        static let editCategory = "edit_category"
        static let settings = "settings"
        static let scan = "scan"
        static let currencySelection = "currency_selection"
        static let currencyList = "currency_list"
        static let recurring = "recurring"
        static let editRecurring = "edit_recurring"
        static let legalPrivacy = "legal_privacy"
        static let legalTerms = "legal_terms"
        static let feedbackFlow = "feedback_flow"
        static let sendFeedback = "send_feedback"
        static let appLockPromo = "app_lock_promo"
    }

    /// Stable non-PII button identifiers for `button_click` events.
    enum Button {
        static let addTransaction = "add_transaction"
        static let openSettings = "open_settings"
        static let openInsights = "open_insights"
        static let openScan = "open_scan"
        static let scrollToTop = "scroll_to_top"
        static let flipSummaryCard = "flip_summary_card"
        static let openTransaction = "open_transaction"
        static let saveTransaction = "save_transaction"
        static let deleteTransaction = "delete_transaction"
        static let scanBillFromForm = "scan_bill_from_form"
        static let takePhoto = "take_photo"
        static let selectLibrary = "select_library"
        static let exportBackup = "export_backup"
        static let importBackup = "import_backup"
        static let manageCategories = "manage_categories"
        static let manageRecurring = "manage_recurring"
        static let openCurrency = "open_currency"
        static let openPrivacy = "open_privacy"
        static let openTerms = "open_terms"
        static let sendFeedback = "send_feedback"
        static let clearLocalData = "clear_local_data"
        static let currencyContinue = "currency_continue"
        static let selectCurrency = "select_currency"
        static let excludeRecurringToggle = "exclude_recurring_toggle"
        static let addCategory = "add_category"
        static let editCategory = "edit_category"
        static let deleteCategory = "delete_category"
        static let pauseRecurring = "pause_recurring"
        static let skipRecurring = "skip_recurring"
        static let editRecurring = "edit_recurring"
        static let deleteRecurring = "delete_recurring"
        static let saveRecurring = "save_recurring"
        static let monthPrevious = "month_previous"
        static let monthNext = "month_next"
        static let groupByDate = "group_by_date"
        static let groupByCategory = "group_by_category"
        static let searchTransactions = "search_transactions"
        static let reviewLovingIt = "review_loving_it"
        static let reviewHaveSuggestion = "review_have_suggestion"
        static let reviewLeaveReview = "review_leave_review"
        static let reviewSendFeedback = "review_send_feedback"
        static let reviewDismiss = "review_dismiss"
        static let appLockPromoEnable = "app_lock_promo_enable"
        static let appLockPromoNotNow = "app_lock_promo_not_now"
        static let appLockToggle = "app_lock_toggle"
    }

    enum Event {
        static let buttonClick = "button_click"
        static let txnSave = "txn_save"
        static let txnDelete = "txn_delete"
        static let receiptScanStart = "receipt_scan_start"
        static let receiptScanResult = "receipt_scan_result"
        static let categoryAdd = "category_add"
        static let categoryEdit = "category_edit"
        static let exportBackup = "export_backup"
        static let importBackup = "import_backup"
        static let clearDataConfirm = "clear_data_confirm"
        static let featureExposure = "feature_exposure"
        static let reviewEligibilityPassed = "review_eligibility_passed"
        static let reviewEligibilityFailed = "review_eligibility_failed"
        static let reviewTriggerTxnMilestone = "review_trigger_txn_milestone"
        static let reviewTriggerReceiptMilestone = "review_trigger_receipt_milestone"
        static let reviewTriggerInsights = "review_trigger_insights"
        static let reviewTriggerSevenDayStreak = "review_trigger_seven_day_streak"
        static let reviewFeedbackFlowPresented = "review_feedback_flow_presented"
        static let reviewPositiveSelected = "review_positive_selected"
        static let reviewNegativeSelected = "review_negative_selected"
        static let reviewFeedbackSubmitted = "review_feedback_submitted"
        static let reviewFeedbackCancelled = "review_feedback_cancelled"
        static let reviewDismissed = "review_dismissed"
        static let reviewAppStoreOpened = "review_app_store_opened"
        static let appLockPromoPresented = "app_lock_promo_presented"
        static let appLockPromoEnable = "app_lock_promo_enable"
        static let appLockPromoDismiss = "app_lock_promo_dismiss"
        static let appLockEnabled = "app_lock_enabled"
        static let appLockDisabled = "app_lock_disabled"
    }

    static func logScreen(_ name: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: name
        ])
    }

    static func logEvent(_ name: String, parameters: [String: String] = [:]) {
        guard !parameters.isEmpty else {
            Analytics.logEvent(name, parameters: nil)
            return
        }
        var payload: [String: Any] = [:]
        for (key, value) in parameters {
            payload[key] = value
        }
        Analytics.logEvent(name, parameters: payload)
    }

    static func logButtonClick(_ button: String, source: String) {
        logEvent(Event.buttonClick, parameters: [
            Param.button: button,
            Param.source: source
        ])
    }

    static func logFeatureExposure(featureKey: String, enabled: Bool) {
        logEvent(Event.featureExposure, parameters: [
            Param.featureKey: featureKey,
            Param.enabled: enabled ? "true" : "false"
        ])
    }

    /// Sets Firebase Analytics user ID to the anonymous Keychain-backed UUID.
    static func configureUserId(_ userId: String) {
        Analytics.setUserID(userId)
    }
}
