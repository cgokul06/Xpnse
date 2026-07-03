//
//  WidgetSnapshotBuilder.swift
//  Xpnse
//

import Foundation

@MainActor
enum WidgetSnapshotBuilder {
    static func build() async throws -> WidgetMonthSnapshot {
        let transactionRepository = SwiftDataTransactionRepository.shared
        let currencyManager = CurrencyManager.shared

        let comparison = calendarComparison()
        let (startDate, endDate) = PeriodDateRangeCalculator.dateRange(
            forOffset: 0,
            comparison: comparison
        )

        let transactions = try await transactionRepository.fetch(startDate: startDate, endDate: endDate)
        var parsedTransactions: [Date: [Transaction]] = [:]

        for transaction in transactions {
            let date = Date(timeIntervalSince1970: transaction.date)
            let dateOfTransaction = Calendar.current.startOfDay(for: date)
            parsedTransactions[dateOfTransaction, default: []].append(transaction)
        }

        let summary = TransactionSummary(
            transactions: parsedTransactions,
            startDate: startDate,
            endDate: endDate,
            range: comparison
        )

        let overviewSlices = summary.financialOverviewSlices()
        let legendSlices = overviewSlices.map(WidgetDonutSlice.init(expenseSlice:))
        let chartSlices = DonutChartSliceBuilder.chartSlices(
            legendSlices: legendSlices,
            allSlices: legendSlices,
            income: summary.totalIncome
        )

        return WidgetMonthSnapshot(
            periodLabel: summary.dateRangeText,
            totalBalance: summary.totalBalance,
            totalIncome: summary.totalIncome,
            totalExpenses: summary.totalExpenses,
            totalSavings: summary.totalSavings,
            currencySymbol: currencyManager.selectedCurrency.symbol,
            donutSlices: chartSlices,
            expenseCategories: legendSlices,
            donutCenterTitle: DonutChartSliceBuilder.centerTitle(income: summary.totalIncome),
            donutCenterAmount: DonutChartSliceBuilder.centerAmount(
                income: summary.totalIncome,
                expenses: summary.totalExpenses,
                savings: summary.totalSavings
            ),
            updatedAt: Date()
        )
    }

    private static func calendarComparison() -> CalendarComparison {
        let raw = UserDefaultsHelper.shared.integer(forKey: .calendarAggregator)
        return CalendarComparison(rawValue: raw) ?? .monthly
    }
}
