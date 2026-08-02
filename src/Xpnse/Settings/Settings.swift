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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Currency Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("settings.preferences")
                        .font(.system(size: 20, weight: .bold))
                        .xpnseAdaptiveForeground()

                    NavigationLink {
                        CurrencyListView(selectedCurrencyCode: selectedCurrency) { selected in
                            selectedCurrency = selected.code
                            CurrencyManager.shared.selectedCurrency = selected
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("settings.currency")
                                .font(.system(size: 16, weight: .medium))
                                .xpnseAdaptiveForeground()
                            Spacer()
                            Text("\(CurrencyManager.shared.selectedCurrency.symbol) \(CurrencyManager.shared.selectedCurrency.code)")
                                .font(.system(size: 16, weight: .semibold))
                                .xpnseAdaptiveForeground()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .xpnseAdaptiveForeground(muted: true)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(AdaptiveBrandSurface.rowBackground(for: colorScheme))
                        .xpnseRoundedCorner()
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        AppAnalytics.logButtonClick(AppAnalytics.Button.openCurrency, source: AppAnalytics.Screen.settings)
                    })

                    appLockRow
                }

                if featureFlags.exportImportEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("settings.data_portability")
                            .font(.system(size: 20, weight: .bold))
                            .xpnseAdaptiveForeground()

                        Button {
                            AppAnalytics.logButtonClick(AppAnalytics.Button.exportBackup, source: AppAnalytics.Screen.settings)
                            AppAnalytics.logFeatureExposure(
                                featureKey: FeatureFlags.Key.exportImportEnabled.rawValue,
                                enabled: true
                            )
                            self.startExport()
                        } label: {
                            self.actionLabel(text: L10n.tr("settings.export"))
                        }

                        Button {
                            AppAnalytics.logButtonClick(AppAnalytics.Button.importBackup, source: AppAnalytics.Screen.settings)
                            AppAnalytics.logFeatureExposure(
                                featureKey: FeatureFlags.Key.exportImportEnabled.rawValue,
                                enabled: true
                            )
                            self.showImporter = true
                        } label: {
                            self.actionLabel(text: L10n.tr("settings.import"))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("settings.categories")
                        .font(.system(size: 20, weight: .bold))
                        .xpnseAdaptiveForeground()

                    NavigationLink {
                        ManageCategoriesView()
                    } label: {
                        self.actionLabel(text: L10n.tr("category.manage"))
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        AppAnalytics.logButtonClick(AppAnalytics.Button.manageCategories, source: AppAnalytics.Screen.settings)
                    })
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("common.recurring")
                        .font(.system(size: 20, weight: .bold))
                        .xpnseAdaptiveForeground()

                    NavigationLink {
                        RecurringTransactionsView()
                    } label: {
                        self.actionLabel(text: L10n.tr("settings.manage_recurring"))
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        AppAnalytics.logButtonClick(AppAnalytics.Button.manageRecurring, source: AppAnalytics.Screen.settings)
                    })
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("settings.legal")
                        .font(.system(size: 20, weight: .bold))
                        .xpnseAdaptiveForeground()

                    Button {
                        AppAnalytics.logButtonClick(AppAnalytics.Button.openPrivacy, source: AppAnalytics.Screen.settings)
                        presentedLegalDocument = .privacyPolicy
                    } label: {
                        self.actionLabel(text: L10n.tr("settings.privacy_policy"))
                    }

                    Button {
                        AppAnalytics.logButtonClick(AppAnalytics.Button.openTerms, source: AppAnalytics.Screen.settings)
                        presentedLegalDocument = .termsAndConditions
                    } label: {
                        self.actionLabel(text: L10n.tr("settings.terms_conditions"))
                    }
                }

                VStack {
                    Button(role: .destructive) {
                        AppAnalytics.logButtonClick(AppAnalytics.Button.clearLocalData, source: AppAnalytics.Screen.settings)
                        showClearDataConfirm = true
                    } label: {
                        Text("settings.clear_local_data")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                #if DEBUG
                VStack(alignment: .leading, spacing: 10) {
                    Text("Debug")
                        .font(.system(size: 20, weight: .bold))
                        .xpnseAdaptiveForeground()

                    Button(role: .destructive) {
                        // Forces a fatal crash so Crashlytics can upload on next launch.
                        fatalError("SnapLedger DEBUG Crashlytics test crash")
                    } label: {
                        self.actionLabel(text: "Test Crashlytics Crash")
                    }
                }
                #endif

                Text(appVersionLabel)
                    .font(.system(size: 12, weight: .medium))
                    .xpnseAdaptiveForeground(muted: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding()
        }
        .gradientNavigationBackground()
        .onAppear {
            AppAnalytics.logScreen(AppAnalytics.Screen.settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusAppLockSettings)) { _ in
            highlightAppLock = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                highlightAppLock = false
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    self.dismiss()
                }, label: {
                    Image(systemName: "xmark")
                        .bold()
                        .padding(.all, 8)
                })
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
                    do {
                        let didAccess = fileURL.startAccessingSecurityScopedResource()
                        defer {
                            if didAccess {
                                fileURL.stopAccessingSecurityScopedResource()
                            }
                        }
                        let content = try String(contentsOf: fileURL, encoding: .utf8)
                        try await exportService.importAllData(content)
                        selectedCurrency = CurrencyManager.shared.selectedCurrency.code
                        importResultText = L10n.tr("settings.import_success")
                        AppAnalytics.logEvent(
                            AppAnalytics.Event.importBackup,
                            parameters: [AppAnalytics.Param.result: "success"]
                        )
                    } catch {
                        importResultText = L10n.tr("settings.import_failed", error.localizedDescription)
                        AppAnalytics.logEvent(
                            AppAnalytics.Event.importBackup,
                            parameters: [AppAnalytics.Param.result: "fail"]
                        )
                        UserSatisfactionEngine.shared.track(.criticalErrorOccurred)
                    }
                    UserEngagementCoordinator.shared.endBusyWork(.importExport)
                    isWorking = false
                    showImportResult = true
                }
            case .failure(let error):
                importResultText = L10n.tr("settings.import_failed", error.localizedDescription)
                AppAnalytics.logEvent(
                    AppAnalytics.Event.importBackup,
                    parameters: [AppAnalytics.Param.result: "fail"]
                )
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
                    await FirebaseTransactionManager.shared.clearAll()
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
    }

    private var appVersionLabel: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return L10n.tr("settings.version", short, build)
    }

    private var appLockRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("settings.app_lock")
                    .font(.system(size: 16, weight: .medium))
                    .xpnseAdaptiveForeground()
                Text("settings.app_lock_subtitle")
                    .font(.system(size: 13, weight: .regular))
                    .xpnseAdaptiveForeground(muted: true)
            }
            Spacer(minLength: 8)
            Toggle(
                "",
                isOn: Binding(
                    get: { appLock.isEnabled },
                    set: { newValue in
                        Task { await toggleAppLock(to: newValue) }
                    }
                )
            )
            .labelsHidden()
            .disabled(isTogglingAppLock || !appLock.canEvaluateDeviceOwnerAuthentication)
            .id(appLock.isEnabled)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            AdaptiveBrandSurface.rowBackground(for: colorScheme)
                .overlay {
                    if highlightAppLock {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 2)
                    }
                }
        )
        .xpnseRoundedCorner()
        .id("appLockRow")
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
            enabled ? AppAnalytics.Event.appLockEnabled : AppAnalytics.Event.appLockDisabled
        )
        AppAnalytics.logFeatureExposure(featureKey: "app_lock", enabled: enabled)
    }

    private func actionLabel(text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .medium))
            .xpnseAdaptiveForeground()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(AdaptiveBrandSurface.rowBackground(for: colorScheme))
            .xpnseRoundedCorner()
    }

    private func startExport() {
        Task {
            do {
                isWorking = true
                UserEngagementCoordinator.shared.beginBusyWork(.importExport)
                let backup = try await exportService.exportAllData()
                exportDocument = BackupDocument(text: backup)
                exportFilename = "snapledger_backup.json"
                showExporter = true
                UserEngagementCoordinator.shared.endBusyWork(.importExport)
                isWorking = false
                AppAnalytics.logEvent(
                    AppAnalytics.Event.exportBackup,
                    parameters: [AppAnalytics.Param.result: "success"]
                )
            } catch {
                UserEngagementCoordinator.shared.endBusyWork(.importExport)
                isWorking = false
                importResultText = L10n.tr("settings.export_failed", error.localizedDescription)
                showImportResult = true
                AppAnalytics.logEvent(
                    AppAnalytics.Event.exportBackup,
                    parameters: [AppAnalytics.Param.result: "fail"]
                )
            }
        }
    }
}
