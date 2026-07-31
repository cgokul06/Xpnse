//
//  CoordinatedHomeView.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI
import Combine

struct CoordinatedHomeView: View {
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @StateObject var billScannerService: BillScannerService = BillScannerService()
    @State private var engagement = UserEngagementCoordinator.shared

    var body: some View {
        NavigationStack(path: $homeCoordinator.path) {
            Home()
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .transactions:
                        AddTransactionView(billScannerService: billScannerService)
                    case .editTransaction(let transaction):
                        AddTransactionView(
                            billScannerService: billScannerService,
                            transaction: transaction
                        )
                    case .settings:
                        Settings()
                    case .billScanner:
                        if FeatureFlags.shared.receiptScanEnabled {
                            BillScannerView(billScannerService: billScannerService)
                        } else {
                            EmptyView()
                        }
                    case .insights:
                        if FeatureFlags.shared.insightsEnabled {
                            InsightsView()
                        } else {
                            EmptyView()
                        }
                    }
                }
        }
        .onAppear {
            engagement.attach(engine: .shared)
            engagement.markSettledPastLaunch()
            engagement.noteAppBecameActive()
            syncBusyWork(for: homeCoordinator.path)
            engagement.reconcile()
        }
        .onChange(of: homeCoordinator.path) { _, newPath in
            syncBusyWork(for: newPath)
            engagement.reconcile()
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            engagement.reconcile()
            engagement.checkPresentationGate()
        }
        .sheet(item: presentedEngagementBinding) { presentation in
            switch presentation {
            case .appReview(let opportunity):
                FeedbackFlowView(opportunity: opportunity)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var presentedEngagementBinding: Binding<EngagementPresentation?> {
        Binding(
            get: { engagement.presentedEngagement },
            set: { newValue in
                if newValue == nil, engagement.presentedEngagement != nil {
                    engagement.dismissCurrentEngagement(reportToEngine: true)
                }
            }
        )
    }

    private func syncBusyWork(for path: [HomeRoute]) {
        engagement.endBusyWork(.addOrEditTransaction)
        engagement.endBusyWork(.billScanner)
        engagement.endBusyWork(.manageCategories)
        engagement.endBusyWork(.manageRecurring)
        engagement.endBusyWork(.settingsCriticalFlow)

        guard let top = path.last else { return }
        switch top {
        case .transactions, .editTransaction:
            engagement.beginBusyWork(.addOrEditTransaction)
        case .billScanner:
            engagement.beginBusyWork(.billScanner)
        case .settings:
            break
        case .insights:
            break
        }
    }
}
