//
//  HomeScreenViewModel.swift
//  Xpnse
//
//  Created by Gokul C on 22/10/25.
//

import Combine
import Foundation

enum CalendarComparison: Int {
//    case fortnightly = 1 // once in two weeks
    case monthly = 2
    case yearly = 3
}

@MainActor
final class HomeScreenViewModel: ObservableObject {
    @Published var currentCalendarComparator: CalendarComparison
    @Published private(set) var transactionSummaryDict: [Int: TransactionSummary] = [:]
    @Published var currentKey: Int = 0
    @Published private(set) var isLoading: Bool = true

    private let transactionManager: FirebaseTransactionManager = .shared
    private let calendar = Calendar.current
    private let prefetchWindow = 6  // how many units (months, quarters, etc.) to prefetch
    let maxFuturisticRange: Int = 12

    /// Set of keys we currently have cached (-4, -3, -2, -1, 0)
    private(set) var loadedKeys: Set<Int> = []

    init() {
        let currentSelection = UserDefaultsHelper.shared.integer(forKey: .calendarAggregator)
        if let val = CalendarComparison(rawValue: currentSelection) {
            self.currentCalendarComparator = val
        } else {
            self.currentCalendarComparator = .monthly
        }

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
        // Example: fetch last 6 months including current (0, -1, -2, -3, -4, -5)
        let preCurrentKeys = (-(prefetchWindow - 1)...0)
        await fetchData(forKeys: Array(preCurrentKeys))
        let postCurrentKeys = (1...maxFuturisticRange)
        await fetchData(forKeys: Array(postCurrentKeys))
    }

    // MARK: - Data Prefetching
    func prefetchIfNeeded(currentKey: Int) async {
        // If user reaches the second-oldest cached key, prefetch more backwards
        guard let minKey = loadedKeys.min(), currentKey <= minKey + 1 else { return }

        let nextRange = ((minKey - prefetchWindow)..<minKey)
        await fetchData(forKeys: Array(nextRange))
    }

    // MARK: - Fetch Logic
    private func fetchData(forKeys keys: [Int]) async {
        let newKeys = keys.filter { !loadedKeys.contains($0) }

        guard !newKeys.isEmpty else { return }

        for key in newKeys {
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

    // MARK: - Compute Date Range for a Key
    private func computeDateRange(forOffset offset: Int) -> (Date, Date) {
        let today = Date()

        switch currentCalendarComparator {
        case .monthly:
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: today),
                  let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)),
                  let range = calendar.range(of: .day, in: .month, for: monthDate),
                  let endOfMonth = calendar.date(bySetting: .day, value: range.count, of: startOfMonth)
            else { return (today, today) }
            return (startOfMonth, endOfMonth)

//        case .fortnightly:
//            let daysToSubtract = offset * 14
//            guard let start = calendar.date(byAdding: .day, value: daysToSubtract, to: today),
//                  let end = calendar.date(byAdding: .day, value: 13, to: start)
//            else { return (today, today) }
//            return (start, end)

        case .yearly:
            guard let yearDate = calendar.date(byAdding: .year, value: offset, to: today),
                  let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: yearDate)),
                  let endOfYear = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear)
            else { return (today, today) }
            return (startOfYear, endOfYear)
        }
    }
}
