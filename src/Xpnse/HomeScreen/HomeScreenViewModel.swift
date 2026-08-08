//
//  HomeScreenViewModel.swift
//  Xpnse
//
//  Created by Gokul C on 22/10/25.
//

import Combine
import Foundation

@MainActor
final class HomeScreenViewModel: ObservableObject {
    @Published var currentCalendarComparator: CalendarComparison
    @Published var transactionSummaryDict: [Int: TransactionSummary] = [:]
    @Published var currentKey: Int = 0
    @Published private(set) var isLoading: Bool = true

    private let transactionManager: FirebaseTransactionManager = .shared
    private let calendar = Calendar.current
    /// How far from `currentKey` to keep cached summaries (pager needs ±1).
    private let cacheRadius = 2
    let maxFuturisticRange: Int = 12
    private var cancellables = Set<AnyCancellable>()

    /// Set of keys we currently have cached
    private(set) var loadedKeys: Set<Int> = []

    init() {
        let currentSelection = UserDefaultsHelper.shared.integer(forKey: .calendarAggregator)
        if let val = CalendarComparison(rawValue: currentSelection) {
            self.currentCalendarComparator = val
        } else {
            self.currentCalendarComparator = .monthly
        }

        setupObservers()

        Task {
            await fetchCurrentMonthData()
            await fetchInitialNearbySetOfData()
        }
    }

    func fetchCurrentMonthData() async {
        await fetchData(forKeys: [0])
        self.isLoading = false
    }

    // MARK: - Initial Prefetch
    func fetchInitialNearbySetOfData() async {
        await fetchData(forKeys: Array((-cacheRadius)...cacheRadius))
        evictDistantKeys(around: currentKey)
    }

    // MARK: - Data Prefetching
    func prefetchIfNeeded(currentKey: Int) async {
        let keys = retainedKeys(around: currentKey)
        await fetchData(forKeys: keys)
        evictDistantKeys(around: currentKey)
    }

    func refreshVisibleData() async {
        let keysToRefresh = retainedKeys(around: currentKey)
        await fetchData(forKeys: keysToRefresh, forceReload: true)
        evictDistantKeys(around: currentKey)
    }

    private func setupObservers() {
        transactionManager.changesPublisher
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshVisibleData() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch Logic
    private func fetchData(forKeys keys: [Int], forceReload: Bool = false) async {
        let targetKeys = forceReload ? keys : keys.filter { !loadedKeys.contains($0) }

        guard !targetKeys.isEmpty else { return }

        for key in targetKeys {
            do {
                let (startDate, endDate) = computeDateRange(forOffset: key)
                try await transactionManager.loadTransactions(
                    startDate: startDate,
                    endDate: endDate,
                    range: self.currentCalendarComparator
                ) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let summary):
                            self?.transactionSummaryDict[key] = summary
                            self?.loadedKeys.insert(key)
                        case .failure(let error):
                            print("Error listening to transactions:", error)
                        }
                    }
                }
            } catch {
                print("❌ Failed to fetch for key \(key): \(error)")
            }
        }
    }

    private func retainedKeys(around key: Int) -> [Int] {
        let lower = key - cacheRadius
        let upper = min(key + cacheRadius, maxFuturisticRange)
        guard lower <= upper else { return [key] }
        return Array(lower...upper)
    }

    private func evictDistantKeys(around key: Int) {
        let keep = Set(retainedKeys(around: key))
        let stale = loadedKeys.subtracting(keep)
        guard !stale.isEmpty else { return }

        for staleKey in stale {
            transactionSummaryDict.removeValue(forKey: staleKey)
            loadedKeys.remove(staleKey)
        }
    }

    // MARK: - Compute Date Range for a Key
    private func computeDateRange(forOffset offset: Int) -> (Date, Date) {
        let range = PeriodDateRangeCalculator.dateRange(
            forOffset: offset,
            comparison: currentCalendarComparator,
            calendar: calendar
        )
        return (range.start, range.end)
    }
}
