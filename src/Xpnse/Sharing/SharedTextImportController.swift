//
//  SharedTextImportController.swift
//  Xpnse
//

import Combine
import Foundation
import SwiftUI
import UIKit

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

        if SharedImageInboxStore.hasContent {
            await processSharedImage(
                billScannerService: billScannerService,
                homeCoordinator: homeCoordinator
            )
            return
        }

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

    private func processSharedImage(
        billScannerService: BillScannerService,
        homeCoordinator: NavigationCoordinator<HomeRoute>
    ) async {
        isProcessing = true
        isAnalyzing = true
        alertMessage = nil
        defer {
            isProcessing = false
            isAnalyzing = false
        }

        let imageData = SharedImageInboxStore.read()
        SharedImageInboxStore.clear()

        guard let imageData,
              let image = UIImage(data: imageData)
        else {
            alertMessage = L10n.tr("share.empty_image")
            return
        }

        guard FeatureFlags.shared.receiptScanEnabled else {
            alertMessage = L10n.tr("share.receipt_scan_unavailable")
            return
        }

        guard FoundationModelsAvailability.isAvailable else {
            alertMessage = FoundationModelsAvailability.unavailabilityMessage
                ?? L10n.tr("share.receipt_scan_unavailable")
            return
        }

        homeCoordinator.popToRoot()
        billScannerService.extractedTransaction = nil
        await billScannerService.scanBill(from: image)

        if billScannerService.extractedTransaction != nil {
            if homeCoordinator.path.last != .transactions {
                homeCoordinator.push(.transactions)
            }
        } else {
            alertMessage = billScannerService.errorMessage ?? L10n.tr("share.empty_image")
        }
    }
}
