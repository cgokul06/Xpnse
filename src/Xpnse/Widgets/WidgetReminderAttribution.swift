//
//  WidgetReminderAttribution.swift
//  Xpnse
//

import Foundation

/// Remembers a widget Add Expense open for the current foreground session.
@MainActor
final class WidgetReminderAttribution {
    static let shared = WidgetReminderAttribution()

    private var family: String?

    func noteOpened(family: String) {
        self.family = family
    }

    func noteBackground() {
        family = nil
    }

    func noteExpenseSavedIfAttributed() {
        guard let family else { return }
        self.family = nil
        AppAnalytics.logEvent(AppAnalytics.Event.widgetTransactionSaved, parameters: [
            AppAnalytics.Param.txnType: TransactionType.expense.rawValue,
            AppAnalytics.Param.source: AppAnalytics.TxnSource.widgetBalance.rawValue,
            AppAnalytics.Param.widgetFamily: family
        ])
    }
}
