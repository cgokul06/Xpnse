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
    }

    enum Screen {
        static let home = "home"
        static let insights = "insights"
        static let addTransaction = "add_transaction"
        static let manageCategories = "manage_categories"
        static let settings = "settings"
        static let scan = "scan"
    }

    enum Event {
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

    static func logFeatureExposure(featureKey: String, enabled: Bool) {
        logEvent(Event.featureExposure, parameters: [
            Param.featureKey: featureKey,
            Param.enabled: enabled ? "true" : "false"
        ])
    }
}
