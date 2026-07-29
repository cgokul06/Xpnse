//
//  FeatureFlags.swift
//  Xpnse
//

import Foundation
import Observation

/// Remote-configurable feature gates with offline-safe defaults (all enabled).
@MainActor
@Observable
final class FeatureFlags {
    static let shared = FeatureFlags()

    private(set) var insightsEnabled = true
    private(set) var receiptScanEnabled = true
    private(set) var exportImportEnabled = true

    enum Key: String, CaseIterable {
        case insightsEnabled = "insights_enabled"
        case receiptScanEnabled = "receipt_scan_enabled"
        case exportImportEnabled = "export_import_enabled"

        var defaultEnabled: Bool { true }
    }

    func apply(boolValues: [Key: Bool]) {
        insightsEnabled = boolValues[.insightsEnabled] ?? Key.insightsEnabled.defaultEnabled
        receiptScanEnabled = boolValues[.receiptScanEnabled] ?? Key.receiptScanEnabled.defaultEnabled
        exportImportEnabled = boolValues[.exportImportEnabled] ?? Key.exportImportEnabled.defaultEnabled
    }

    func isEnabled(_ key: Key) -> Bool {
        switch key {
        case .insightsEnabled: return insightsEnabled
        case .receiptScanEnabled: return receiptScanEnabled
        case .exportImportEnabled: return exportImportEnabled
        }
    }
}
