//
//  Settings.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct Settings: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedCurrency: String = CurrencyManager.shared.selectedCurrency.code
    @State private var exportService = ExportImportService()
    @State private var exportDocument = BackupDocument()
    @State private var exportFilename = "snapledger_backup.json"
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showImportResult = false
    @State private var importResultText = ""
    @State private var showClearDataConfirm = false
    @State private var isWorking = false
    @State private var featureFlags = FeatureFlags.shared
    @State private var presentedLegalDocument: LegalDocument?
    @State private var appLock = AppLockController.shared
    @State private var isTogglingAppLock = false
    @State private var highlightAppLock = false
    /// `deep_link` when Settings was opened by the App Lock promo or `snapledger://settings/app-lock`.
    @State private var appLockEntrySource = "settings"
    @State private var widgetPrivacyEnabled = WidgetPrivacyManager.isEnabled
    @State private var expenseReminderEnabled = ExpenseReminderScheduler.shared.isEnabled
    @State private var numberFormatPreference = NumberFormatPreference.current
    @ObservedObject private var monthlyCycleStore = MonthlyCycleStore.shared

    #if DEBUG
    @State private var debugShareURL: URL?
    @State private var showDebugShare = false
    @State private var debugLogEmptyAlert = false
    #endif

    var body: some View {
        List {
            generalSection
            privacySecuritySection
            transactionsSection
            if featureFlags.exportImportEnabled {
                dataSection
            }
            // Premium section reserved for future paid plans.
            supportSection
            legalSection
            dangerZoneSection
            #if DEBUG
            debugSection
            #endif
            versionFooter
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .gradientNavigationBackground()
        .onAppear {
            AppAnalytics.logScreen(AppAnalytics.Screen.settings)
            numberFormatPreference = NumberFormatPreference.current
            if !featureFlags.exportImportEnabled {
                AppAnalytics.logFeatureUnavailable(feature: "export_import", reason: "remote_config_off")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusAppLockSettings)) { _ in
            appLockEntrySource = "deep_link"
            highlightAppLock = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                highlightAppLock = false
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .bold()
                        .padding(.all, 8)
                }
                .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
            }

            ToolbarItem(placement: .principal) {
                Text("settings.title")
                    .font(.title2)
                    .fontWeight(.bold)
                    .xpnseAdaptiveForeground()
            }
        }
        .navigationBarBackButtonHidden()
        .overlay {
            if isWorking {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.2)
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .allowsHitTesting(true)
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { _ in }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                guard let fileURL = files.first else { return }
                Task { @MainActor in
                    isWorking = true
                    UserEngagementCoordinator.shared.beginBusyWork(.importExport)
                    let startedAt = Date()
                    do {
                        let didAccess = fileURL.startAccessingSecurityScopedResource()
                        defer {
                            if didAccess {
                                fileURL.stopAccessingSecurityScopedResource()
                            }
                        }
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        let recordCount = try await exportService.importAllData(content)
                        selectedCurrency = CurrencyManager.shared.selectedCurrency.code
                        importResultText = L10n.tr("settings.import_success")
                        AppAnalytics.logEvent(AppAnalytics.Event.dataImportCompleted, parameters: [
                            AppAnalytics.Param.result: AppAnalytics.Outcome.success.rawValue,
                            AppAnalytics.Param.recordCountBucket: AppAnalytics.Bucket.recordCount(recordCount)
                        ])
                        AnalyticsUserProperties.refresh()
                    } catch {
                        importResultText = L10n.tr("settings.import_failed", error.localizedDescription)
                        let reason = ExportImportService.failureReason(for: error)
                        logImportFailed(reason)
                        if reason == .unexpected {
                            AppDiagnostics.recordNonFatal(operation: .import, feature: "import_export", reason: reason, error: error)
                        }
                        UserSatisfactionEngine.shared.track(.criticalErrorOccurred)
                    }
                    AppAnalytics.logIfSlow(operation: "import", since: startedAt)
                    UserEngagementCoordinator.shared.endBusyWork(.importExport)
                    isWorking = false
                    showImportResult = true
                }
            case .failure(let error):
                importResultText = L10n.tr("settings.import_failed", error.localizedDescription)
                logImportFailed(.permissionDenied)
                showImportResult = true
            }
        }
        .alert("settings.import_status", isPresented: $showImportResult) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(importResultText)
        }
        .alert("settings.clear_local_data_confirm_title", isPresented: $showClearDataConfirm) {
            Button("common.cancel", role: .cancel) { }
            Button("settings.clear_local_data", role: .destructive) {
                Task {
                    AppAnalytics.logEvent(AppAnalytics.Event.clearDataConfirm)
                    isWorking = true
                    UserEngagementCoordinator.shared.beginBusyWork(.settingsCriticalFlow)
                    if await FirebaseTransactionManager.shared.clearAll() {
                        AppAnalytics.logEvent(AppAnalytics.Event.localDataClearCompleted, parameters: [
                            AppAnalytics.Param.source: AppAnalytics.Screen.settings,
                            AppAnalytics.Param.result: AppAnalytics.Outcome.success.rawValue
                        ])
                    } else {
                        AppAnalytics.logEvent(AppAnalytics.Event.localDataClearFailed, parameters: [
                            AppAnalytics.Param.failureReason: AppAnalytics.FailureReason.persistence.rawValue
                        ])
                    }
                    UserEngagementCoordinator.shared.endBusyWork(.settingsCriticalFlow)
                    isWorking = false
                }
            }
        } message: {
            Text("settings.clear_local_data_confirm_message")
        }
        .fullScreenCover(item: $presentedLegalDocument) { document in
            LegalDocumentView(document: document)
        }
        #if DEBUG
        .sheet(isPresented: $showDebugShare) {
            if let debugShareURL {
                DebugShareSheet(items: [debugShareURL])
            }
        }
        .alert("settings.debug_logs_empty_title", isPresented: $debugLogEmptyAlert) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text("settings.debug_logs_empty_message")
        }
        #endif
    }

    // MARK: - Sections

    private var generalSection: some View {
        Section {
            NavigationLink {
                CurrencyListView(selectedCurrencyCode: selectedCurrency) { selected in
                    selectedCurrency = selected.code
                    CurrencyManager.shared.selectedCurrency = selected
                }
                .onAppear {
                    AppAnalytics.logButtonClick(AppAnalytics.Button.openCurrency, source: AppAnalytics.Screen.settings)
                }
            } label: {
                settingsLabel(
                    titleKey: "settings.currency",
                    systemImage: "indianrupeesign.circle",
                    value: "\(CurrencyManager.shared.selectedCurrency.symbol) \(CurrencyManager.shared.selectedCurrency.code)"
                )
            }

            NavigationLink {
                NumberFormatSettingsView()
            } label: {
                settingsLabel(
                    titleKey: "settings.number_format",
                    systemImage: "number",
                    value: numberFormatPreferenceLabel
                )
            }

            NavigationLink {
                MonthlyCycleSettingsView()
            } label: {
                settingsLabel(
                    titleKey: "settings.monthly_cycle",
                    systemImage: "calendar",
                    value: "\(monthlyCycleStore.configuration.startDay)",
                    subtitleKey: "settings.monthly_cycle.description"
                )
            }

            NavigationLink {
                ManageCategoriesView()
                    .onAppear {
                        AppAnalytics.logButtonClick(AppAnalytics.Button.manageCategories, source: AppAnalytics.Screen.settings)
                    }
            } label: {
                settingsLabel(titleKey: "settings.categories", systemImage: "square.grid.2x2")
            }
        } header: {
            Text("settings.general")
        }
    }

    private var privacySecuritySection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { appLock.isEnabled },
                set: { newValue in
                    Task { await toggleAppLock(to: newValue) }
                }
            )) {
                settingsLabel(
                    titleKey: "settings.app_lock",
                    systemImage: "lock.fill",
                    subtitleKey: "settings.app_lock_subtitle"
                )
            }
            .disabled(isTogglingAppLock || !appLock.canEvaluateDeviceOwnerAuthentication)
            .id(appLock.isEnabled)
            .overlay {
                if highlightAppLock {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 2)
                }
            }
            .accessibilityHint(Text("settings.app_lock_subtitle"))

            Toggle(isOn: Binding(
                get: { widgetPrivacyEnabled },
                set: { setWidgetPrivacyEnabled($0) }
            )) {
                settingsLabel(
                    titleKey: "settings.widget_privacy.title",
                    systemImage: "eye.slash",
                    subtitleKey: "settings.widget_privacy.subtitle"
                )
            }
            .accessibilityHint(Text("settings.widget_privacy.subtitle"))
        } header: {
            Text("settings.privacy_security")
        }
    }

    private var transactionsSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { expenseReminderEnabled },
                set: { newValue in
                    expenseReminderEnabled = newValue
                    AppAnalytics.logEvent(
                        AppAnalytics.Event.checkInPreferenceChanged,
                        parameters: [AppAnalytics.Param.enabled: AppAnalytics.flag(newValue)]
                    )
                    Task {
                        await ExpenseReminderScheduler.shared.setEnabled(newValue)
                        AnalyticsUserProperties.refresh()
                    }
                }
            )) {
                settingsLabel(
                    titleKey: "settings.expense_reminder",
                    systemImage: "bell",
                    subtitleKey: "settings.expense_reminder.subtitle"
                )
            }
            .accessibilityHint(Text("settings.expense_reminder.subtitle"))
            #if DEBUG
            Text("Debug timing: notification 30 minutes after you leave. Widget version 1 at 30 minutes, version 2 at 1 hour.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            #endif

            NavigationLink {
                RecurringTransactionsView()
                    .onAppear {
                        AppAnalytics.logButtonClick(AppAnalytics.Button.manageRecurring, source: AppAnalytics.Screen.settings)
                    }
            } label: {
                settingsLabel(
                    titleKey: "settings.recurring_transactions",
                    systemImage: "repeat"
                )
            }
        } header: {
            Text("settings.transactions")
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                AppAnalytics.logButtonClick(AppAnalytics.Button.exportBackup, source: AppAnalytics.Screen.settings)
                AppAnalytics.logFeatureExposure(
                    featureKey: FeatureFlags.Key.exportImportEnabled.rawValue,
                    enabled: true
                )
                startExport()
            } label: {
                settingsLabel(
                    titleKey: "settings.export_data",
                    systemImage: "square.and.arrow.up",
                    subtitleKey: "settings.export_data_subtitle"
                )
            }
            .tint(AdaptiveBrandSurface.primaryForeground(for: colorScheme))

            Button {
                AppAnalytics.logButtonClick(AppAnalytics.Button.importBackup, source: AppAnalytics.Screen.settings)
                AppAnalytics.logFeatureExposure(
                    featureKey: FeatureFlags.Key.exportImportEnabled.rawValue,
                    enabled: true
                )
                showImporter = true
            } label: {
                settingsLabel(
                    titleKey: "settings.import_data",
                    systemImage: "square.and.arrow.down",
                    subtitleKey: "settings.import_data_subtitle"
                )
            }
            .tint(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
        } header: {
            Text("settings.data")
        }
    }

    private var supportSection: some View {
        Section {
            NavigationLink {
                SendFeedbackView(marksReviewOutcome: false, showsCloseButton: false)
                    .onAppear {
                        AppAnalytics.logButtonClick(
                            AppAnalytics.Button.sendFeedback,
                            source: AppAnalytics.Screen.settings
                        )
                    }
            } label: {
                settingsLabel(
                    titleKey: "settings.send_feedback",
                    systemImage: "bubble.left.and.text.bubble.right"
                )
            }
        } header: {
            Text("settings.support")
        }
    }

    private var legalSection: some View {
        Section {
            Button {
                AppAnalytics.logButtonClick(AppAnalytics.Button.openPrivacy, source: AppAnalytics.Screen.settings)
                presentedLegalDocument = .privacyPolicy
            } label: {
                settingsLabel(
                    titleKey: "settings.privacy_policy",
                    systemImage: "hand.raised.fill"
                )
            }
            .tint(AdaptiveBrandSurface.primaryForeground(for: colorScheme))

            Button {
                AppAnalytics.logButtonClick(AppAnalytics.Button.openTerms, source: AppAnalytics.Screen.settings)
                presentedLegalDocument = .termsAndConditions
            } label: {
                settingsLabel(
                    titleKey: "settings.terms_conditions",
                    systemImage: "doc.text"
                )
            }
            .tint(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
        } header: {
            Text("settings.legal")
        }
    }

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                AppAnalytics.logButtonClick(AppAnalytics.Button.clearLocalData, source: AppAnalytics.Screen.settings)
                showClearDataConfirm = true
            } label: {
                settingsLabel(
                    titleKey: "settings.clear_local_data",
                    systemImage: "trash",
                    subtitleKey: "settings.clear_local_data_subtitle",
                    destructive: true
                )
            }
            .accessibilityAddTraits(.isButton)
        } header: {
            Text("settings.danger_zone")
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .padding(.top, 8)
    }

    #if DEBUG
    private var debugSection: some View {
        Section {
            Button {
                if let url = DeviceDebugLogger.prepareShareURL() {
                    debugShareURL = url
                    showDebugShare = true
                } else {
                    debugLogEmptyAlert = true
                }
            } label: {
                settingsLabel(
                    titleKey: "settings.debug_share_logs",
                    systemImage: "square.and.arrow.up",
                    subtitleKey: "settings.debug_share_logs_subtitle"
                )
            }

            Button(role: .destructive) {
                DeviceDebugLogger.clear()
            } label: {
                settingsLabel(
                    titleKey: "settings.debug_clear_logs",
                    systemImage: "trash",
                    destructive: true
                )
            }

            Button(role: .destructive) {
                fatalError("SnapLedger DEBUG Crashlytics test crash")
            } label: {
                settingsLabel(
                    titleKey: "settings.debug_crash",
                    systemImage: "bolt.trianglebadge.exclamationmark.fill",
                    destructive: true
                )
            }
        } header: {
            Text("settings.debug")
        }
    }
    #endif

    private var versionFooter: some View {
        Section {
            EmptyView()
        } footer: {
            VStack(spacing: 4) {
                Text("SnapLedger")
                    .font(.footnote.weight(.semibold))
                Text(appVersionLabel)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Row chrome

    private func settingsLabel(
        titleKey: String,
        systemImage: String,
        value: String? = nil,
        subtitleKey: String? = nil,
        destructive: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .font(.body)
                .foregroundStyle(destructive ? Color.red : AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(titleKey))
                    .font(.body)
                    .foregroundStyle(destructive ? Color.red : AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                    .multilineTextAlignment(.leading)
                if let subtitleKey {
                    Text(LocalizedStringKey(subtitleKey))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let value {
                Text(value)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

    private var appVersionLabel: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return L10n.tr("settings.version", short, build)
    }

    private var numberFormatPreferenceLabel: String {
        switch numberFormatPreference {
        case .auto:
            L10n.tr("settings.number_format.auto_short")
        case .lakhCrore:
            L10n.tr("settings.number_format.lakh_crore")
        case .million:
            L10n.tr("settings.number_format.million")
        }
    }

    private func toggleAppLock(to enabled: Bool) async {
        guard !isTogglingAppLock else { return }
        isTogglingAppLock = true
        defer { isTogglingAppLock = false }
        AppAnalytics.logButtonClick(
            AppAnalytics.Button.appLockToggle,
            source: AppAnalytics.Screen.settings
        )
        let success = await appLock.setEnabled(enabled)
        guard success else { return }
        AppAnalytics.logEvent(
            enabled ? AppAnalytics.Event.appLockEnabled : AppAnalytics.Event.appLockDisabled,
            parameters: [AppAnalytics.Param.source: appLockEntrySource]
        )
        AnalyticsUserProperties.refresh()
    }

    private func logImportFailed(_ reason: AppAnalytics.FailureReason) {
        AppAnalytics.logEvent(
            AppAnalytics.Event.dataImportFailed,
            parameters: [AppAnalytics.Param.failureReason: reason.rawValue]
        )
    }

    private func setWidgetPrivacyEnabled(_ enabled: Bool) {
        WidgetPrivacyManager.setEnabled(enabled)
        widgetPrivacyEnabled = enabled
        WidgetPrivacyManager.reloadAllWidgets()
    }

    private func startExport() {
        let format = [AppAnalytics.Param.format: "json"]
        AppAnalytics.logEvent(AppAnalytics.Event.exportStarted, parameters: format)
        Task {
            let startedAt = Date()
            do {
                isWorking = true
                UserEngagementCoordinator.shared.beginBusyWork(.importExport)
                let backup = try await exportService.exportAllData()
                exportDocument = BackupDocument(text: backup)
                exportFilename = "snapledger_backup.json"
                showExporter = true
                UserEngagementCoordinator.shared.endBusyWork(.importExport)
                isWorking = false
                AppAnalytics.logEvent(AppAnalytics.Event.exportCompleted, parameters: format)
            } catch {
                UserEngagementCoordinator.shared.endBusyWork(.importExport)
                isWorking = false
                importResultText = L10n.tr("settings.export_failed", error.localizedDescription)
                showImportResult = true
                var parameters = format
                parameters[AppAnalytics.Param.failureReason] = AppAnalytics.FailureReason.persistence.rawValue
                AppAnalytics.logEvent(AppAnalytics.Event.exportFailed, parameters: parameters)
                AppDiagnostics.recordNonFatal(operation: .export, feature: "import_export", reason: .persistence, error: error)
            }
            AppAnalytics.logIfSlow(operation: "export", since: startedAt)
        }
    }
}

#if DEBUG
import UIKit

private struct DebugShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
