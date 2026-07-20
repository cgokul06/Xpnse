//
//  InsightsViewModel.swift
//  Xpnse
//

import Combine
import Foundation

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published private(set) var expenseTrend: ExpenseTrendChartModel = ExpenseTrendChartModel(
        points: [],
        year: Calendar.current.component(.year, from: Date()),
        projectedMonth: nil,
        hasProjection: false
    )
    @Published private(set) var year: Int
    @Published private(set) var isLoading = false

    private let transactionRepository: TransactionRepository
    private let recurringRepository: RecurringRepository
    private let calendar: Calendar
    private var cancellables = Set<AnyCancellable>()

    init(
        transactionRepository: TransactionRepository = SwiftDataTransactionRepository.shared,
        recurringRepository: RecurringRepository = SwiftDataRecurringRepository.shared,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.transactionRepository = transactionRepository
        self.recurringRepository = recurringRepository
        self.calendar = calendar
        self.year = calendar.component(.year, from: now)

        transactionRepository.changesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                Task { await self?.reload() }
            }
            .store(in: &cancellables)
    }

    var expenseTrendPoints: [ExpenseTrendPoint] {
        expenseTrend.points
    }

    func onAppear() {
        Task { await reload() }
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }

        guard let yearStart = startOfYear(year),
              let fetchStart = calendar.date(byAdding: .month, value: -MonthExpenseExtrapolationEngine.defaultLookbackMonths, to: yearStart),
              let end = endOfYear(year)
        else {
            expenseTrend = emptyTrend()
            return
        }

        do {
            async let transactionsTask = transactionRepository.fetch(startDate: fetchStart, endDate: end)
            async let recurringTask = recurringRepository.fetchAll()

            let transactions = try await transactionsTask
            let recurringItems = (try? await recurringTask) ?? []
            let expenses = transactions.filter { $0.type == .expense }

            expenseTrend = ExpenseTrendBuilder.build(
                expenses: expenses,
                year: year,
                recurringItems: recurringItems,
                calendar: calendar
            )
        } catch {
            expenseTrend = emptyTrend()
        }
    }

    private func emptyTrend() -> ExpenseTrendChartModel {
        ExpenseTrendChartModel(
            points: [],
            year: year,
            projectedMonth: nil,
            hasProjection: false
        )
    }

    private func startOfYear(_ year: Int) -> Date? {
        calendar.date(from: DateComponents(year: year, month: 1, day: 1))
    }

    private func endOfYear(_ year: Int) -> Date? {
        guard let startOfNext = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return nil }
        return startOfNext.addingTimeInterval(-1)
    }
}
