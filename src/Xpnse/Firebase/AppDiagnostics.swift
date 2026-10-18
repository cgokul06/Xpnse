//
//  AppDiagnostics.swift
//  Xpnse
//
//  Crashlytics non-fatals for unexpected, actionable failures. The recorded error
//  carries only bounded identifiers; never the underlying error text, which can
//  include user data.
//

import Foundation
import FirebaseCrashlytics

enum AppDiagnostics {
    enum Operation: String {
        case transactionAdd = "transaction_add"
        case transactionUpdate = "transaction_update"
        case transactionDelete = "transaction_delete"
        case recurringCreate = "recurring_create"
        case recurringUpdate = "recurring_update"
        case recurringPause = "recurring_pause"
        case categorySave = "category_save"
        case export
        case `import`
        case scan
        case insightsLoad = "insights_load"
        case homeLoad = "home_load"
        case localDataClear = "local_data_clear"
    }

    static func recordNonFatal(
        operation: Operation,
        feature: String,
        reason: AppAnalytics.FailureReason = .unexpected,
        error: Error? = nil
    ) {
        var userInfo: [String: Any] = [
            "operation": operation.rawValue,
            "feature": feature,
            "reason": reason.rawValue
        ]
        if let error {
            let nsError = error as NSError
            userInfo["underlying_domain"] = nsError.domain
            userInfo["underlying_code"] = nsError.code
        }
        let sanitized = NSError(
            domain: "com.snapledger.diagnostics.\(operation.rawValue)",
            code: code(for: reason),
            userInfo: userInfo
        )
        #if DEBUG
        print("[diagnostics] non-fatal \(operation.rawValue) feature=\(feature) reason=\(reason.rawValue)")
        #endif
        Crashlytics.crashlytics().record(error: sanitized)
    }

    // MARK: - Startup

    private static var launchStartedAt: Date?
    private static var didReportStartup = false

    static func markLaunchStarted() {
        launchStartedAt = Date()
    }

    /// Reported once per process, when the first meaningful screen (Home state or currency setup) resolves.
    static func markStartupCompleted(destination: String) {
        guard !didReportStartup, let launchStartedAt else { return }
        didReportStartup = true
        AppAnalytics.logEvent(AppAnalytics.Event.appStartupCompleted, parameters: [
            AppAnalytics.Param.destination: destination,
            AppAnalytics.Param.durationBucket: AppAnalytics.Bucket.duration(Date().timeIntervalSince(launchStartedAt))
        ])
    }

    private static func code(for reason: AppAnalytics.FailureReason) -> Int {
        switch reason {
        case .validation: return 1
        case .persistence: return 2
        case .permissionDenied: return 3
        case .unsupportedFormat: return 4
        case .unavailable: return 5
        case .unexpected: return 6
        case .formClosed: return 7
        case .noTextFound: return 8
        case .invalidImage: return 9
        }
    }
}
