//
//  AnalyticsInstrumentationTests.swift
//  XpnseTests
//

import UserNotifications
import XCTest
@testable import Xpnse

@MainActor
final class AnalyticsInstrumentationTests: XCTestCase {
    private var recorder: RecordingAnalytics!
    private var previousLogger: AnalyticsLogging!
    private var previousActivation: ActivationAnalytics!
    private var previousLoadMarker: (() -> PendingTransactionFormMarker?)!
    private var previousSaveMarker: ((PendingTransactionFormMarker?) -> Void)!
    private var activationRecorded = false
    private var activationBaselineChecked = false
    private var storedMarker: PendingTransactionFormMarker?
    private let installedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private var now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        recorder = RecordingAnalytics()
        previousLogger = AppAnalytics.logger
        AppAnalytics.logger = recorder
        AppAnalytics.loggedUnavailableFeatures.removeAll()

        activationRecorded = false
        activationBaselineChecked = false
        previousActivation = ActivationAnalytics.shared
        ActivationAnalytics.shared = ActivationAnalytics(
            isRecorded: { [unowned self] in activationRecorded },
            markRecorded: { [unowned self] in activationRecorded = true },
            isBaselineChecked: { [unowned self] in activationBaselineChecked },
            markBaselineChecked: { [unowned self] in activationBaselineChecked = true },
            installationDate: { [unowned self] in installedAt },
            now: { [unowned self] in now }
        )

        storedMarker = nil
        previousLoadMarker = TransactionFormAbandonment.loadMarker
        previousSaveMarker = TransactionFormAbandonment.saveMarker
        TransactionFormAbandonment.loadMarker = { [unowned self] in storedMarker }
        TransactionFormAbandonment.saveMarker = { [unowned self] in storedMarker = $0 }
    }

    override func tearDown() {
        AppAnalytics.logger = previousLogger
        AppAnalytics.loggedUnavailableFeatures.removeAll()
        ActivationAnalytics.shared = previousActivation
        TransactionFormAbandonment.loadMarker = previousLoadMarker
        TransactionFormAbandonment.saveMarker = previousSaveMarker
        recorder = nil
        super.tearDown()
    }

    // MARK: - Buckets

    func testTransactionCountBuckets() {
        XCTAssertEqual(AppAnalytics.Bucket.txnCount(0), "0")
        XCTAssertEqual(AppAnalytics.Bucket.txnCount(1), "1")
        XCTAssertEqual(AppAnalytics.Bucket.txnCount(2), "2_5")
        XCTAssertEqual(AppAnalytics.Bucket.txnCount(5), "2_5")
        XCTAssertEqual(AppAnalytics.Bucket.txnCount(6), "6_20")
        XCTAssertEqual(AppAnalytics.Bucket.txnCount(20), "6_20")
        XCTAssertEqual(AppAnalytics.Bucket.txnCount(21), "21_plus")
    }

    func testRecordCountBuckets() {
        XCTAssertEqual(AppAnalytics.Bucket.recordCount(0), "0")
        XCTAssertEqual(AppAnalytics.Bucket.recordCount(10), "1_10")
        XCTAssertEqual(AppAnalytics.Bucket.recordCount(11), "11_100")
        XCTAssertEqual(AppAnalytics.Bucket.recordCount(1000), "101_1000")
        XCTAssertEqual(AppAnalytics.Bucket.recordCount(1001), "1001_plus")
    }

    func testDurationBuckets() {
        XCTAssertEqual(AppAnalytics.Bucket.duration(0.5), "lt_1s")
        XCTAssertEqual(AppAnalytics.Bucket.duration(1), "1_3s")
        XCTAssertEqual(AppAnalytics.Bucket.duration(3), "3_10s")
        XCTAssertEqual(AppAnalytics.Bucket.duration(10), "gt_10s")
    }

    // MARK: - User properties

    func testUserPropertyValuesAreBoundedAndContainNoFinancialData() {
        let expense = Transaction(
            id: UUID().uuidString,
            type: .expense,
            categoryId: "other",
            amount: 250,
            title: "Coffee at Blue Tokai",
            currency: CurrencyOption(id: 1, code: "INR", name: "Indian Rupee", symbol: "₹")
        )
        let values = AnalyticsUserProperties.values(
            transactions: [expense],
            recurring: [],
            notificationStatus: .provisional,
            appLockEnabled: true,
            expenseCheckInEnabled: false
        )

        XCTAssertEqual(values[AppAnalytics.UserProperty.hasExpense], "true")
        XCTAssertEqual(values[AppAnalytics.UserProperty.hasIncome], "false")
        XCTAssertEqual(values[AppAnalytics.UserProperty.hasRecurring], "false")
        XCTAssertEqual(values[AppAnalytics.UserProperty.txnBucket], "1")
        XCTAssertEqual(values[AppAnalytics.UserProperty.notificationsAuthorized], "provisional")
        XCTAssertEqual(values[AppAnalytics.UserProperty.appLockEnabled], "true")
        XCTAssertEqual(values[AppAnalytics.UserProperty.expenseCheckIn], "disabled")

        for value in values.values {
            XCTAssertFalse(value.contains("Blue Tokai"))
            XCTAssertFalse(value.contains("250"))
        }
    }

    // MARK: - Events

    func testTransactionSavedUsesBoundedParameters() {
        AppAnalytics.logTransactionSaved(
            type: .expense,
            source: .widgetAdd,
            mode: .create,
            recurring: false,
            reminder: nil
        )

        let event = try? XCTUnwrap(recorder.events(named: AppAnalytics.Event.txnSave).first)
        XCTAssertEqual(event?.parameters[AppAnalytics.Param.txnType], "expense")
        XCTAssertEqual(event?.parameters[AppAnalytics.Param.source], "widget_add")
        XCTAssertEqual(event?.parameters[AppAnalytics.Param.mode], "create")
        XCTAssertEqual(event?.parameters[AppAnalytics.Param.recurring], "false")
        XCTAssertEqual(event?.parameters[AppAnalytics.Param.reminder], "na")
    }

    func testFeatureUnavailableLogsOncePerSession() {
        AppAnalytics.logFeatureUnavailable(feature: "scan", reason: "remote_config_off")
        AppAnalytics.logFeatureUnavailable(feature: "scan", reason: "remote_config_off")

        XCTAssertEqual(recorder.count(AppAnalytics.Event.featureUnavailable), 1)
    }

    func testSlowOperationOnlyLogsAtThreshold() {
        AppAnalytics.logIfSlow(operation: "export", since: Date())
        XCTAssertEqual(recorder.count(AppAnalytics.Event.slowOperation), 0)

        AppAnalytics.logIfSlow(operation: "export", since: Date().addingTimeInterval(-5))
        let event = recorder.events(named: AppAnalytics.Event.slowOperation).first
        XCTAssertEqual(event?.parameters[AppAnalytics.Param.operation], "export")
        XCTAssertEqual(event?.parameters[AppAnalytics.Param.durationBucket], "3_10s")
    }

    func testEducationOutcomeEventsMapFailureReason() {
        EducationAnalytics.outcomeApplied(.actionFailed, campaignID: RecurringReminderJourney.campaignID)
        EducationAnalytics.outcomeApplied(.declined, campaignID: RecurringReminderJourney.campaignID)

        let failed = recorder.events(named: AppAnalytics.Event.educationActionFailed)
        XCTAssertEqual(failed.count, 1)
        XCTAssertEqual(failed.first?.parameters[AppAnalytics.Param.failureReason], "permission_denied")
        XCTAssertEqual(recorder.events.count, 1)
    }

    func testSlowOperationBucketsStartAtTheThreshold() {
        XCTAssertEqual(AppAnalytics.slowOperationThreshold, 2)
        XCTAssertEqual(AppAnalytics.Bucket.slowDuration(2), "2_3s")
        XCTAssertEqual(AppAnalytics.Bucket.slowDuration(2.9), "2_3s")
        XCTAssertEqual(AppAnalytics.Bucket.slowDuration(3), "3_10s")
        XCTAssertEqual(AppAnalytics.Bucket.slowDuration(10), "gt_10s")

        AppAnalytics.logIfSlow(operation: "import", since: Date().addingTimeInterval(-2.5))
        XCTAssertEqual(
            recorder.events(named: AppAnalytics.Event.slowOperation).first?.parameters[AppAnalytics.Param.durationBucket],
            "2_3s"
        )
    }

    func testEducationFormClosedIsACancellationNotAFailure() {
        EducationAnalytics.outcomeApplied(.actionFailed, campaignID: IncomeSetupJourney.campaignID)

        XCTAssertEqual(recorder.count(AppAnalytics.Event.educationActionFailed), 0)
        let cancelled = recorder.events(named: AppAnalytics.Event.educationActionCancelled)
        XCTAssertEqual(cancelled.count, 1)
        XCTAssertEqual(cancelled.first?.parameters[AppAnalytics.Param.journey], IncomeSetupJourney.campaignID)
    }

    // MARK: - First transaction

    func testFirstTransactionSavedFiresOnceForCreates() {
        now = installedAt.addingTimeInterval(30 * 60)
        AppAnalytics.logTransactionSaved(type: .expense, source: .home, mode: .create, recurring: false, reminder: nil)
        AppAnalytics.logTransactionSaved(type: .income, source: .home, mode: .create, recurring: false, reminder: nil)

        let first = recorder.events(named: AppAnalytics.Event.firstTransactionSaved)
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first.first?.parameters[AppAnalytics.Param.txnType], "expense")
        XCTAssertEqual(first.first?.parameters[AppAnalytics.Param.source], "home")
        XCTAssertEqual(first.first?.parameters[AppAnalytics.Param.hoursSinceInstallBucket], "lt_1h")
        XCTAssertEqual(recorder.count(AppAnalytics.Event.txnSave), 2)
    }

    func testEditSaveIsNotAFirstTransaction() {
        AppAnalytics.logTransactionSaved(type: .expense, source: .edit, mode: .edit, recurring: false, reminder: nil)
        XCTAssertEqual(recorder.count(AppAnalytics.Event.firstTransactionSaved), 0)
    }

    func testExistingDataBaselineSuppressesFirstTransaction() {
        ActivationAnalytics.shared.checkBaseline(existingTransactionCount: 12)
        AppAnalytics.logTransactionSaved(type: .expense, source: .home, mode: .create, recurring: false, reminder: nil)
        XCTAssertEqual(recorder.count(AppAnalytics.Event.firstTransactionSaved), 0)
    }

    func testEmptyBaselineStillAllowsFirstTransaction() {
        ActivationAnalytics.shared.checkBaseline(existingTransactionCount: 0)
        ActivationAnalytics.shared.checkBaseline(existingTransactionCount: 3)
        AppAnalytics.logTransactionSaved(type: .expense, source: .scan, mode: .create, recurring: false, reminder: nil)
        XCTAssertEqual(recorder.count(AppAnalytics.Event.firstTransactionSaved), 1)
    }

    func testHoursSinceInstallBuckets() {
        let hour: TimeInterval = 3600
        XCTAssertEqual(AppAnalytics.Bucket.hoursSinceInstall(0.5 * hour), "lt_1h")
        XCTAssertEqual(AppAnalytics.Bucket.hoursSinceInstall(1 * hour), "1_24h")
        XCTAssertEqual(AppAnalytics.Bucket.hoursSinceInstall(24 * hour), "1_3d")
        XCTAssertEqual(AppAnalytics.Bucket.hoursSinceInstall(72 * hour), "gt_3d")
    }

    // MARK: - Form abandonment

    private func marker(id: UUID, backgroundedAt: Date) -> PendingTransactionFormMarker {
        PendingTransactionFormMarker(
            presentationId: id,
            txnType: "expense",
            source: "home",
            mode: "create",
            stage: TransactionFormStage.partiallyFilled.rawValue,
            backgroundedAt: backgroundedAt
        )
    }

    func testBackgroundingAloneDoesNotAbandon() {
        let id = UUID()
        let backgroundedAt = Date()
        TransactionFormAbandonment.formBackgrounded(marker(id: id, backgroundedAt: backgroundedAt))
        XCTAssertEqual(recorder.count(AppAnalytics.Event.transactionFormAbandoned), 0)

        let abandoned = TransactionFormAbandonment.formReturned(
            presentationId: id,
            now: backgroundedAt.addingTimeInterval(5 * 60)
        )
        XCTAssertFalse(abandoned)
        XCTAssertNil(storedMarker)
        XCTAssertEqual(recorder.count(AppAnalytics.Event.transactionFormAbandoned), 0)
    }

    func testReturningAfterTimeoutAbandonsOnce() {
        let id = UUID()
        let backgroundedAt = Date()
        TransactionFormAbandonment.formBackgrounded(marker(id: id, backgroundedAt: backgroundedAt))
        let returnAt = backgroundedAt.addingTimeInterval(TransactionFormAbandonment.backgroundTimeout)

        XCTAssertTrue(TransactionFormAbandonment.formReturned(presentationId: id, now: returnAt))
        XCTAssertFalse(TransactionFormAbandonment.formReturned(presentationId: id, now: returnAt))
        TransactionFormAbandonment.resolveAtLaunch()

        let events = recorder.events(named: AppAnalytics.Event.transactionFormAbandoned)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.parameters[AppAnalytics.Param.exitReason], "background_timeout")
        XCTAssertEqual(events.first?.parameters[AppAnalytics.Param.stage], "partially_filled")
    }

    func testRelaunchResolvesAnOrphanedForm() {
        TransactionFormAbandonment.formBackgrounded(marker(id: UUID(), backgroundedAt: Date()))
        TransactionFormAbandonment.resolveAtLaunch()
        TransactionFormAbandonment.resolveAtLaunch()

        XCTAssertEqual(recorder.count(AppAnalytics.Event.transactionFormAbandoned), 1)
        XCTAssertNil(storedMarker)
    }

    func testFinishedFormDoesNotResolveAsAbandoned() {
        let id = UUID()
        TransactionFormAbandonment.formBackgrounded(marker(id: id, backgroundedAt: Date()))
        TransactionFormAbandonment.formFinished(presentationId: id)
        TransactionFormAbandonment.resolveAtLaunch()

        XCTAssertEqual(recorder.count(AppAnalytics.Event.transactionFormAbandoned), 0)
    }

    func testNavigationExitLogsAndClearsMarker() {
        let id = UUID()
        TransactionFormAbandonment.formBackgrounded(marker(id: id, backgroundedAt: Date()))
        TransactionFormAbandonment.formLeftByNavigation(
            presentationId: id,
            type: .income,
            source: .widgetAdd,
            mode: .create,
            stage: .empty
        )
        TransactionFormAbandonment.resolveAtLaunch()

        let events = recorder.events(named: AppAnalytics.Event.transactionFormAbandoned)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.parameters[AppAnalytics.Param.exitReason], "navigation")
        XCTAssertEqual(events.first?.parameters[AppAnalytics.Param.stage], "empty")
    }

    func testFormStageClassification() {
        XCTAssertEqual(TransactionFormStage.classify(hasAmount: false, hasDescription: false, canSave: false), .empty)
        XCTAssertEqual(TransactionFormStage.classify(hasAmount: true, hasDescription: false, canSave: false), .partiallyFilled)
        XCTAssertEqual(TransactionFormStage.classify(hasAmount: true, hasDescription: true, canSave: true), .readyToSave)
    }

    // MARK: - Recurring and Insights

    func testRecurringScheduleChangeIsOneSummaryPerSave() {
        XCTAssertNil(AppAnalytics.recurringScheduleChangeParameters([]))
        XCTAssertEqual(
            AppAnalytics.recurringScheduleChangeParameters(["end_date"]),
            [AppAnalytics.Param.changeType: "end_date", AppAnalytics.Param.changedFields: "end_date"]
        )
        XCTAssertEqual(
            AppAnalytics.recurringScheduleChangeParameters(["start_date", "frequency"]),
            [AppAnalytics.Param.changeType: "multiple", AppAnalytics.Param.changedFields: "frequency,start_date"]
        )
    }

    func testInsightsViewedStateMapping() {
        XCTAssertNil(InsightsView.viewedState(phase: .loading, didFailToLoad: false))
        XCTAssertEqual(InsightsView.viewedState(phase: .empty, didFailToLoad: false), .empty)
        XCTAssertEqual(InsightsView.viewedState(phase: .empty, didFailToLoad: true), .error)
        XCTAssertEqual(InsightsView.viewedState(phase: .ready, didFailToLoad: true), .ready)
    }

    // MARK: - Failure mapping

    func testBillScanFailureReasonMapping() {
        typealias ScanError = BillScannerService.BillScannerError
        XCTAssertEqual(BillScannerService.failureReason(for: ScanError.noTextFound), .noTextFound)
        XCTAssertEqual(BillScannerService.failureReason(for: ScanError.invalidImage), .invalidImage)
        XCTAssertEqual(BillScannerService.failureReason(for: ScanError.modelUnavailable("off")), .unavailable)
        XCTAssertEqual(BillScannerService.failureReason(for: NSError(domain: "x", code: 1)), .unexpected)
    }
}
