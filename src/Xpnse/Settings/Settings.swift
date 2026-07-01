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
                    Text("Preferences")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    NavigationLink {
                        CurrencyListView(selectedCurrencyCode: selectedCurrency) { selected in
                            selectedCurrency = selected.code
                            CurrencyManager.shared.selectedCurrency = selected
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("Currency")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(CurrencyManager.shared.selectedCurrency.symbol) \(CurrencyManager.shared.selectedCurrency.code)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(.white.opacity(0.1))
                        .xpnseRoundedCorner()
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Data Portability")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Button {
                        self.startExport()
                    } label: {
                        self.actionLabel(text: "Export All Data")
                    }

                    Button {
                        self.showImporter = true
                    } label: {
                        self.actionLabel(text: "Import All Data")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Categories")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    NavigationLink {
                        ManageCategoriesView()
                    } label: {
                        self.actionLabel(text: "Manage Categories")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Recurring")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    NavigationLink {
                        RecurringTransactionsView()
                    } label: {
                        self.actionLabel(text: "Manage Recurring Transactions")
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
                        Text("Clear Local Data")
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
            Text("Version: 0.0.0")
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
                .foregroundStyle(Color.white)
            }

            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
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
                        importResultText = "Import completed successfully."
                    } catch {
                        importResultText = "Import failed: \(error.localizedDescription)"
                    }
                    showImportResult = true
                }
            case .failure(let error):
                importResultText = "Import failed: \(error.localizedDescription)"
                showImportResult = true
            }
        }
        .alert("Import Status", isPresented: $showImportResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importResultText)
        }
    }

    private func actionLabel(text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(.white.opacity(0.1))
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
                importResultText = "Export failed: \(error.localizedDescription)"
                showImportResult = true
            }
        }
    }
}
