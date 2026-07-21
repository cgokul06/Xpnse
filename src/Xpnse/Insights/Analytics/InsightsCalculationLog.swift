//
//  InsightsCalculationLog.swift
//  Xpnse
//

import Foundation
import OSLog

/// Console-visible calculation dumps for Insights analytics (filter: subsystem SnapLedger, category InsightsCalc).
enum InsightsCalculationLog {
    private static let logger = Logger(
        subsystem: "com.snapledgerapp.ios",
        category: "InsightsCalc"
    )

    static func baselineMonths(
        candidates: [(Int, Int)],
        kept: [(Int, Int)],
        volumes: [(key: String, volume: Double, kept: Bool)]
    ) {
        let candidateText = candidates.map { "\($0.0)-\($0.1)" }.joined(separator: ", ")
        let keptText = kept.map { "\($0.0)-\($0.1)" }.joined(separator: ", ")
        logger.info("Baseline months candidates=[\(candidateText, privacy: .public)] kept=[\(keptText, privacy: .public)]")
        for row in volumes {
            logger.info(
                "  month \(row.key, privacy: .public) volume=\(row.volume, format: .fixed(precision: 2)) kept=\(row.kept)"
            )
        }
    }

    static func categoryBaselines(
        focusLabel: String,
        baselineMonths: [(Int, Int)],
        rows: [CategoryBaselineCalcRow]
    ) {
        let months = baselineMonths.map { "\($0.0)-\($0.1)" }.joined(separator: ", ")
        logger.info(
            "Category health focus=\(focusLabel, privacy: .public) usual=avg monthly spend in [\(months, privacy: .public)] (complete lookback only). Bands: under<\(FinancialHealthRules.categoryWithinBand.lowerBound) within…\(FinancialHealthRules.categoryWithinBand.upperBound) approaching…\(FinancialHealthRules.categoryApproachingMax) over>"
        )
        for row in rows {
            let monthParts = row.perMonthAmounts
                .map { "\($0.month)=\(String(format: "%.2f", $0.amount))" }
                .joined(separator: ", ")
            logger.info(
                "  \(row.name, privacy: .public) focus=\(row.focusAmount, format: .fixed(precision: 2)) perMonth=[\(monthParts, privacy: .public)] sum=\(row.baselineSum, format: .fixed(precision: 2)) usual(avg)=\(row.rollingAverage, format: .fixed(precision: 2)) utilization=\(row.utilization, format: .fixed(precision: 3)) (\(Int((row.utilization * 100).rounded()))%) status=\(row.status.rawValue, privacy: .public)"
            )
        }
    }

    static func detectedEvents(
        focus: String,
        discretionaryCount: Int,
        recurringExcluded: Int,
        events: [String]
    ) {
        logger.info(
            "Detected events focus=\(focus, privacy: .public) discretionaryTx=\(discretionaryCount) recurringExcluded=\(recurringExcluded) count=\(events.count)"
        )
        for line in events {
            logger.info("  event \(line, privacy: .public)")
        }
        if events.isEmpty {
            logger.info("  (none — need rare category-month spikes or annual-style one-offs)")
        }
    }

    struct CategoryBaselineCalcRow {
        let name: String
        let focusAmount: Double
        let perMonthAmounts: [(month: String, amount: Double)]
        let baselineSum: Double
        let rollingAverage: Double
        let utilization: Double
        let status: InsightsCategoryHealthStatus
    }
}
