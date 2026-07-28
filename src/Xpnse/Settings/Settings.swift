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
    @State private var isWorking = false

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
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("settings.data_portability")
                        .font(.system(size: 20, weight: .bold))
                        .xpnseAdaptiveForeground()

                    Button {
                        self.startExport()
                    } label: {
                        self.actionLabel(text: L10n.tr("settings.export"))
                    }

                    Button {
                        self.showImporter = true
                    } label: {
                        self.actionLabel(text: L10n.tr("settings.import"))
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
                }

                VStack {
                    Button(role: .destructive) {
                        Task {
                            isWorking = true
                            await FirebaseTransactionManager.shared.clearAll()
                            isWorking = false
                        }
                    } label: {
                        Text("settings.clear_local_data")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding()
        }
        .gradientNavigationBackground()
        .safeAreaInset(edge: .bottom, content: {
            Text("settings.version")
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 20)
        })
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
                ProgressView()
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
                Task {
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
                    } catch {
                        importResultText = L10n.tr("settings.import_failed", error.localizedDescription)
                    }
                    showImportResult = true
                }
            case .failure(let error):
                importResultText = L10n.tr("settings.import_failed", error.localizedDescription)
                showImportResult = true
            }
        }
        .alert("settings.import_status", isPresented: $showImportResult) {
            Button("common.ok", role: .cancel) { }
        } message: {
            Text(importResultText)
        }
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
                let backup = try await exportService.exportAllData()
                exportDocument = BackupDocument(text: backup)
                exportFilename = "snapledger_backup.json"
                showExporter = true
                isWorking = false
            } catch {
                isWorking = false
                importResultText = L10n.tr("settings.export_failed", error.localizedDescription)
                showImportResult = true
            }
        }
    }
}
