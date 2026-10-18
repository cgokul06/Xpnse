//
//  ActivationAnalytics.swift
//  Xpnse
//
//  `first_transaction_saved`: once per install. The flag lives in UserDefaults, so it survives
//  Clear Local Data and resets only when the app (and its App Group data) is removed.
//

import Foundation

final class ActivationAnalytics {
    static var shared = ActivationAnalytics(
        isRecorded: { UserDefaultsHelper.shared.bool(forKey: .analyticsFirstTransactionLogged) },
        markRecorded: { UserDefaultsHelper.shared.set(true, forKey: .analyticsFirstTransactionLogged) },
        isBaselineChecked: { UserDefaultsHelper.shared.bool(forKey: .analyticsFirstTransactionBaselineChecked) },
        markBaselineChecked: { UserDefaultsHelper.shared.set(true, forKey: .analyticsFirstTransactionBaselineChecked) },
        installationDate: { UserSatisfactionEngine.shared.installationDate },
        now: Date.init
    )

    private let isRecorded: () -> Bool
    private let markRecorded: () -> Void
    private let isBaselineChecked: () -> Bool
    private let markBaselineChecked: () -> Void
    private let installationDate: () -> Date?
    private let now: () -> Date

    init(
        isRecorded: @escaping () -> Bool,
        markRecorded: @escaping () -> Void,
        isBaselineChecked: @escaping () -> Bool,
        markBaselineChecked: @escaping () -> Void,
        installationDate: @escaping () -> Date?,
        now: @escaping () -> Date
    ) {
        self.isRecorded = isRecorded
        self.markRecorded = markRecorded
        self.isBaselineChecked = isBaselineChecked
        self.markBaselineChecked = markBaselineChecked
        self.installationDate = installationDate
        self.now = now
    }

    /// Called only after a user-initiated create has persisted. Check-and-set runs on the main
    /// actor, so concurrent saves and retries cannot emit twice.
    func noteTransactionSaved(type: TransactionType, source: AppAnalytics.TxnSource) {
        guard !isRecorded() else { return }
        markRecorded()
        markBaselineChecked()
        var parameters = [
            AppAnalytics.Param.txnType: type.rawValue,
            AppAnalytics.Param.source: source.rawValue
        ]
        if let installedAt = installationDate() {
            parameters[AppAnalytics.Param.hoursSinceInstallBucket] =
                AppAnalytics.Bucket.hoursSinceInstall(now().timeIntervalSince(installedAt))
        }
        AppAnalytics.logEvent(AppAnalytics.Event.firstTransactionSaved, parameters: parameters)
    }

    /// One-shot for installs that already had transactions before this event shipped,
    /// so their next save is not misreported as a first transaction.
    func checkBaseline(existingTransactionCount: Int) {
        guard !isBaselineChecked() else { return }
        markBaselineChecked()
        if existingTransactionCount > 0, !isRecorded() {
            markRecorded()
        }
    }
}
