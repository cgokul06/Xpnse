//
//  SharedTextImportController.swift
//  Xpnse
//

import Combine
import Foundation
import SwiftUI

/// Coordinates Share Extension inbox → Foundation Models analysis → Add Transaction.
@MainActor
final class SharedTextImportController: ObservableObject {
    static let shared = SharedTextImportController()

    @Published private(set) var isAnalyzing = false
    @Published var alertMessage: String?
    @Published private(set) var pendingRequestID = UUID()

    private var isProcessing = false

    func markPendingFromDeepLink() {
        pendingRequestID = UUID()
    }

    func processIfNeeded(
        billScannerService: BillScannerService,
        homeCoordinator: NavigationCoordinator<HomeRoute>
    ) async {
        guard !isProcessing else { return }
        guard SharedTextInboxStore.hasContent else { return }

        isProcessing = true
        isAnalyzing = true
        alertMessage = nil
        defer {
            isProcessing = false
            isAnalyzing = false
        }

        let payload = SharedTextInboxStore.read()
        SharedTextInboxStore.clear()

        guard let text = payload?.text else {
            alertMessage = L10n.tr("share.empty_text")
            return
        }

        homeCoordinator.popToRoot()
        await billScannerService.analyzeSharedText(text)

        if billScannerService.extractedTransaction != nil {
            if homeCoordinator.path.last != .transactions {
                homeCoordinator.push(.transactions)
            }
        } else {
            alertMessage = billScannerService.errorMessage ?? L10n.tr("share.not_transaction")
        }
    }
}
