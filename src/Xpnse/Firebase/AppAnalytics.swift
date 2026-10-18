//
//  AppAnalytics.swift
//  Xpnse
//
//  Privacy-safe usability analytics. Never log amounts, merchants,
//  descriptions, category names, emails, or other personal/financial content.
//

import Foundation
import FirebaseAnalytics

protocol AnalyticsLogging: AnyObject {
    func log(_ name: String, parameters: [String: String])
    func setUserProperty(_ value: String?, forName name: String)
}

final class FirebaseAnalyticsLogger: AnalyticsLogging {
    func log(_ name: String, parameters: [String: String]) {
        #if DEBUG
        let keys = parameters.keys.sorted().joined(separator: ",")
        print("[analytics] \(name) keys=[\(keys)]")
        #endif
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

    func setUserProperty(_ value: String?, forName name: String) {
        #if DEBUG
        print("[analytics] user_property \(name)")
        #endif
        Analytics.setUserProperty(value, forName: name)
    }
}

enum AppAnalytics {
    /// Swapped in tests to record events instead of sending them to Firebase.
    static var logger: AnalyticsLogging = FirebaseAnalyticsLogger()

    /// Allowed parameter keys only — keep values non-PII (e.g. "success", "failed", feature ids).
    enum Param {
        static let source = "source"
        static let result = "result"
        static let featureKey = "feature_key"
        static let enabled = "enabled"
        static let button = "button"
        static let campaignVersion = "campaign_version"
        static let cancellationReason = "cancellation_reason"
        static let entryPoint = "entry_point"
        static let widgetFamily = "widget_family"
        static let widgetType = "widget_type"
        static let destination = "destination"
        static let txnType = "txn_type"
        static let mode = "mode"
        static let recurring = "recurring"
        static let reminder = "reminder"
        static let field = "field"
        static let reason = "reason"
        static let failureReason = "failure_reason"
        static let journey = "journey"
        static let trigger = "trigger"
        static let action = "action"
        static let actionType = "action_type"
        static let dismissMethod = "dismiss_method"
        static let state = "state"
        static let txnBucket = "txn_bucket"
        static let setupPath = "setup_path"
        static let recordCountBucket = "record_count_bucket"
        static let stage = "stage"
        static let changeType = "change_type"
        static let changeSource = "change_source"
        static let categoryType = "category_type"
        static let navigationMethod = "navigation_method"
        static let direction = "direction"
        static let format = "format"
        static let method = "method"
        static let feature = "feature"
        static let triggerReason = "trigger_reason"
        static let notificationType = "notification_type"
        static let window = "window"
        static let durationBucket = "duration_bucket"
        static let operation = "operation"
        static let hoursSinceInstallBucket = "hours_since_install_bucket"
        static let exitReason = "exit_reason"
        static let changedFields = "changed_fields"
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
        static let groupByDate = "group_by_date"
        static let groupByCategory = "group_by_category"
        static let openListOptions = "open_list_options"
        static let toggleGroupByCategory = "toggle_group_by_category"
        static let toggleShowUpcomingRecurring = "toggle_show_upcoming_recurring"
        static let toggleFilterExpense = "toggle_filter_expense"
        static let toggleFilterIncome = "toggle_filter_income"
        static let toggleFilterSavings = "toggle_filter_savings"
        static let setSortAscending = "set_sort_ascending"
        static let setSortDescending = "set_sort_descending"
        static let openUpcomingRecurring = "open_upcoming_recurring"
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
        static let featureExposure = "feature_exposure"

        // Transaction lifecycle
        static let transactionFormOpened = "transaction_form_opened"
        static let transactionValidationFailed = "transaction_validation_failed"
        static let transactionSaveFailed = "transaction_save_failed"
        static let transactionFormCancelled = "transaction_form_cancelled"
        static let transactionFormAbandoned = "transaction_form_abandoned"
        static let txnSave = "txn_save"
        static let firstTransactionSaved = "first_transaction_saved"
        static let transactionDeleted = "transaction_deleted"
        static let categoryChanged = "category_changed"

        // Education
        static let educationPresented = "education_presented"
        static let educationActionSelected = "education_action_selected"
        static let educationDismissed = "education_dismissed"
        static let educationCompleted = "education_completed"
        static let educationActionFailed = "education_action_failed"
        static let educationActionCancelled = "education_action_cancelled"

        // Activation
        static let homeStateViewed = "home_state_viewed"
        static let appSetupCompleted = "app_setup_completed"

        // Scanner and share
        static let billScanStarted = "bill_scan_started"
        static let billScanPreviewShown = "bill_scan_preview_shown"
        static let billScanAbandoned = "bill_scan_abandoned"
        static let billScanFailed = "bill_scan_failed"
        static let shareTextAnalyzeStart = "share_text_analyze_start"
        static let shareTextAnalyzeResult = "share_text_analyze_result"

        // Insights, recurring, search, reports
        static let insightsViewed = "insights_viewed"
        static let insightActionSelected = "insight_action_selected"
        static let recurringSetupStarted = "recurring_setup_started"
        static let recurringScheduleChanged = "recurring_schedule_changed"
        static let recurringTransactionPaused = "recurring_transaction_paused"
        static let transactionSearchUsed = "transaction_search_used"
        static let transactionSearchResult = "transaction_search_result"
        static let reportPeriodChanged = "report_period_changed"

        // Categories, data, settings
        static let categoryCreated = "category_created"
        static let categoryEdit = "category_edit"
        static let exportStarted = "export_started"
        static let exportCompleted = "export_completed"
        static let exportFailed = "export_failed"
        static let dataImportCompleted = "data_import_completed"
        static let dataImportFailed = "data_import_failed"
        static let clearDataConfirm = "clear_data_confirm"
        static let localDataClearCompleted = "local_data_clear_completed"
        static let localDataClearFailed = "local_data_clear_failed"

        // Review prompt
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

        // App Lock
        static let appLockPromoPresented = "app_lock_promo_presented"
        static let appLockPromoEnable = "app_lock_promo_enable"
        static let appLockPromoDismiss = "app_lock_promo_dismiss"
        static let appLockEnabled = "app_lock_enabled"
        static let appLockDisabled = "app_lock_disabled"
        static let appLockAuthResult = "app_lock_auth_result"

        // Notifications and widgets
        static let checkInEligible = "check_in_eligible"
        static let checkInScheduleResult = "check_in_schedule_result"
        static let checkInCancelled = "check_in_cancelled"
        static let checkInPreferenceChanged = "check_in_preference_changed"
        static let checkInOpened = "check_in_opened"
        static let checkInConversion = "check_in_conversion"
        static let widgetDestinationOpened = "widget_destination_opened"
        static let widgetTransactionSaved = "widget_transaction_saved"
        static let widgetActionFailed = "widget_action_failed"

        // Diagnostics
        static let featureUnavailable = "feature_unavailable"
        static let appStartupCompleted = "app_startup_completed"
        static let slowOperation = "slow_operation"
    }

    enum UserProperty {
        static let hasExpense = "has_expense"
        static let hasIncome = "has_income"
        static let hasRecurring = "has_recurring"
        static let txnBucket = "txn_bucket"
        static let notificationsAuthorized = "notifications_authorized"
        static let appLockEnabled = "app_lock_enabled"
        static let expenseCheckIn = "expense_check_in"
    }

    // MARK: - Controlled parameter values

    enum TxnSource: String, Hashable {
        case home
        case educationIncome = "education_income"
        case educationExpense = "education_expense"
        case scan
        case shareText = "share_text"
        case shareImage = "share_image"
        case widgetAdd = "widget_add"
        case widgetBalance = "widget_balance"
        case notification
        case insightsSuggestion = "insights_suggestion"
        case edit
    }

    enum TxnMode: String {
        case create
        case edit
        case recurringCreate = "recurring_create"
    }

    enum Outcome: String {
        case success
        case failed
        case cancelled
    }

    enum FailureReason: String {
        case validation
        case persistence
        case permissionDenied = "permission_denied"
        case unsupportedFormat = "unsupported_format"
        case unavailable
        case unexpected
        case formClosed = "form_closed"
        case noTextFound = "no_text_found"
        case invalidImage = "invalid_image"
    }

    enum FeatureState: String {
        case empty
        case ready
        case error
    }

    enum ScanStage: String {
        case capture
        case ocr
        case extraction
        case preview
    }

    enum ScanSource: String {
        case home
        case addForm = "add_form"
        case shareImage = "share_image"
    }

    enum Bucket {
        static func txnCount(_ count: Int) -> String {
            switch count {
            case ..<1: return "0"
            case 1: return "1"
            case 2...5: return "2_5"
            case 6...20: return "6_20"
            default: return "21_plus"
            }
        }

        static func recordCount(_ count: Int) -> String {
            switch count {
            case ..<1: return "0"
            case 1...10: return "1_10"
            case 11...100: return "11_100"
            case 101...1000: return "101_1000"
            default: return "1001_plus"
            }
        }

        static func duration(_ seconds: TimeInterval) -> String {
            switch seconds {
            case ..<1: return "lt_1s"
            case ..<3: return "1_3s"
            case ..<10: return "3_10s"
            default: return "gt_10s"
            }
        }

        /// Starts at `slowOperationThreshold`, so every `slow_operation` lands in a bucket that matches the trigger.
        static func slowDuration(_ seconds: TimeInterval) -> String {
            switch seconds {
            case ..<3: return "2_3s"
            case ..<10: return "3_10s"
            default: return "gt_10s"
            }
        }

        static func hoursSinceInstall(_ seconds: TimeInterval) -> String {
            let hour: TimeInterval = 60 * 60
            switch seconds {
            case ..<hour: return "lt_1h"
            case ..<(24 * hour): return "1_24h"
            case ..<(72 * hour): return "1_3d"
            default: return "gt_3d"
            }
        }
    }

    static func flag(_ value: Bool) -> String { value ? "true" : "false" }

    // MARK: - Logging

    static func logScreen(_ name: String) {
        logger.log(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: name
        ])
    }

    static func logEvent(_ name: String, parameters: [String: String] = [:]) {
        logger.log(name, parameters: parameters)
    }

    static func logButtonClick(_ button: String, source: String) {
        logEvent(Event.buttonClick, parameters: [
            Param.button: button,
            Param.source: source
        ])
    }

    /// Fires when the user opens or invokes a gated feature (Insights, Scan, Export/Import),
    /// not when the feature is merely available. The name is kept for existing GA4 reports.
    static func logFeatureExposure(featureKey: String, enabled: Bool) {
        logEvent(Event.featureExposure, parameters: [
            Param.featureKey: featureKey,
            Param.enabled: flag(enabled)
        ])
    }

    static func logTransactionSaved(
        type: TransactionType,
        source: TxnSource,
        mode: TxnMode,
        recurring: Bool,
        reminder: Bool?
    ) {
        logEvent(Event.txnSave, parameters: [
            Param.txnType: type.rawValue,
            Param.source: source.rawValue,
            Param.mode: mode.rawValue,
            Param.recurring: flag(recurring),
            Param.reminder: reminder.map(flag) ?? "na"
        ])
        if mode != .edit {
            ActivationAnalytics.shared.noteTransactionSaved(type: type, source: source)
        }
    }

    static func logTransactionSaveFailed(type: TransactionType, source: TxnSource, reason: FailureReason) {
        logEvent(Event.transactionSaveFailed, parameters: [
            Param.txnType: type.rawValue,
            Param.source: source.rawValue,
            Param.failureReason: reason.rawValue
        ])
    }

    static func logFormEvent(_ event: String, type: TransactionType, source: TxnSource, mode: TxnMode) {
        logEvent(event, parameters: [
            Param.txnType: type.rawValue,
            Param.source: source.rawValue,
            Param.mode: mode.rawValue
        ])
    }

    /// One `recurring_schedule_changed` per save. `change_type` is the single field or `multiple`;
    /// `changed_fields` is the sorted, comma-joined field set (bounded: frequency, start_date, end_date, reminder).
    static func recurringScheduleChangeParameters(_ fields: [String]) -> [String: String]? {
        let sorted = Array(Set(fields)).sorted()
        guard !sorted.isEmpty else { return nil }
        return [
            Param.changeType: sorted.count == 1 ? sorted[0] : "multiple",
            Param.changedFields: sorted.joined(separator: ",")
        ]
    }

    static func logBillScanFailed(stage: ScanStage, reason: FailureReason) {
        logEvent(Event.billScanFailed, parameters: [
            Param.stage: stage.rawValue,
            Param.failureReason: reason.rawValue
        ])
    }

    static func logFeatureUnavailable(feature: String, reason: String) {
        let key = "\(feature)|\(reason)"
        guard !loggedUnavailableFeatures.contains(key) else { return }
        loggedUnavailableFeatures.insert(key)
        logEvent(Event.featureUnavailable, parameters: [
            Param.feature: feature,
            Param.reason: reason
        ])
    }

    /// Cleared on background so `feature_unavailable` is reported at most once per session.
    static var loggedUnavailableFeatures: Set<String> = []

    static let slowOperationThreshold: TimeInterval = 2

    /// Logs `slow_operation` when `start` is at least `slowOperationThreshold` ago.
    static func logIfSlow(operation: String, since start: Date) {
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed >= slowOperationThreshold else { return }
        logEvent(Event.slowOperation, parameters: [
            Param.operation: operation,
            Param.durationBucket: Bucket.slowDuration(elapsed)
        ])
    }

    /// Sets Firebase Analytics user ID to the anonymous Keychain-backed UUID.
    static func configureUserId(_ userId: String) {
        Analytics.setUserID(userId)
    }
}
