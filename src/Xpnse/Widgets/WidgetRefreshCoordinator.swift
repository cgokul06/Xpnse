//
//  WidgetRefreshCoordinator.swift
//  Xpnse
//

import Combine
import Foundation

@MainActor
final class WidgetRefreshCoordinator {
    static let shared = WidgetRefreshCoordinator()

    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?
    private var needsFollowUpRefresh = false
    private let transactionManager: FirebaseTransactionManager

    private init() {
        self.transactionManager = FirebaseTransactionManager.shared
    }

    func start() {
        guard cancellables.isEmpty else { return }

        transactionManager.changesPublisher
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)

        Task { await refresh() }
    }

    func refresh() async {
        if let refreshTask {
            needsFollowUpRefresh = true
            await refreshTask.value
            if needsFollowUpRefresh {
                needsFollowUpRefresh = false
                await performRefresh()
            }
            return
        }

        refreshTask = Task { await performRefresh() }
        await refreshTask?.value
        refreshTask = nil
    }

    private func performRefresh() async {
        do {
            let snapshot = try await WidgetSnapshotBuilder.build()
            try WidgetDataStore.save(snapshot)
            WidgetTimelineReloader.reloadAll()
        } catch {
            print("Widget snapshot refresh failed: \(error.localizedDescription)")
        }
    }
}
