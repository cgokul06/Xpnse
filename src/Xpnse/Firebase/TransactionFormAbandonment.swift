//
//  TransactionFormAbandonment.swift
//  Xpnse
//
//  Inferred `transaction_form_abandoned`. Explicit close stays `transaction_form_cancelled`.
//
//  Rules:
//  - navigation: the form left the screen without save, delete, or close (for example a deep
//    link popped the stack). Logged when it happens.
//  - background_timeout: the form was open when the app backgrounded and the user did not come
//    back within `backgroundTimeout`, or the process ended while it was in the background.
//    Backgrounding alone never logs; a marker is resolved on return or on the next launch.
//  - At most once per form presentation. Only coarse form state is stored, never field values.
//

import Foundation

enum TransactionFormStage: String {
    case empty
    case partiallyFilled = "partially_filled"
    case readyToSave = "ready_to_save"

    static func classify(hasAmount: Bool, hasDescription: Bool, canSave: Bool) -> TransactionFormStage {
        if canSave { return .readyToSave }
        return hasAmount || hasDescription ? .partiallyFilled : .empty
    }
}

struct PendingTransactionFormMarker: Codable, Equatable {
    var presentationId: UUID
    var txnType: String
    var source: String
    var mode: String
    var stage: String
    var backgroundedAt: Date
}

enum TransactionFormAbandonment {
    static let backgroundTimeout: TimeInterval = 30 * 60

    static var loadMarker: () -> PendingTransactionFormMarker? = {
        guard let data = UserDefaultsHelper.shared.data(forKey: .analyticsPendingFormMarker) else { return nil }
        return try? JSONDecoder().decode(PendingTransactionFormMarker.self, from: data)
    }

    static var saveMarker: (PendingTransactionFormMarker?) -> Void = { marker in
        UserDefaultsHelper.shared.setData(
            marker.flatMap { try? JSONEncoder().encode($0) },
            forKey: .analyticsPendingFormMarker
        )
    }

    static func formBackgrounded(_ marker: PendingTransactionFormMarker) {
        saveMarker(marker)
    }

    /// Returns true when the form is now considered abandoned (the event was logged).
    @discardableResult
    static func formReturned(presentationId: UUID, now: Date = Date()) -> Bool {
        guard let marker = loadMarker(), marker.presentationId == presentationId else { return false }
        saveMarker(nil)
        guard now.timeIntervalSince(marker.backgroundedAt) >= backgroundTimeout else { return false }
        log(marker, exitReason: "background_timeout")
        return true
    }

    /// A new process cannot host the old form, so any surviving marker is an abandoned form.
    static func resolveAtLaunch() {
        guard let marker = loadMarker() else { return }
        saveMarker(nil)
        log(marker, exitReason: "background_timeout")
    }

    static func formLeftByNavigation(
        presentationId: UUID,
        type: TransactionType,
        source: AppAnalytics.TxnSource,
        mode: AppAnalytics.TxnMode,
        stage: TransactionFormStage
    ) {
        if loadMarker()?.presentationId == presentationId {
            saveMarker(nil)
        }
        log(
            PendingTransactionFormMarker(
                presentationId: presentationId,
                txnType: type.rawValue,
                source: source.rawValue,
                mode: mode.rawValue,
                stage: stage.rawValue,
                backgroundedAt: Date()
            ),
            exitReason: "navigation"
        )
    }

    /// Save, delete, or explicit close finished the form; a pending marker must not resolve later.
    static func formFinished(presentationId: UUID) {
        guard loadMarker()?.presentationId == presentationId else { return }
        saveMarker(nil)
    }

    private static func log(_ marker: PendingTransactionFormMarker, exitReason: String) {
        AppAnalytics.logEvent(AppAnalytics.Event.transactionFormAbandoned, parameters: [
            AppAnalytics.Param.txnType: marker.txnType,
            AppAnalytics.Param.source: marker.source,
            AppAnalytics.Param.mode: marker.mode,
            AppAnalytics.Param.stage: marker.stage,
            AppAnalytics.Param.exitReason: exitReason
        ])
    }
}
