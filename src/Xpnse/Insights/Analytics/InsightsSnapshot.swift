//
//  InsightsSnapshot.swift
//  Xpnse
//

import Foundation

enum InsightsFinancialEventKind: String, Codable, Sendable {
    case oneTimeLarge
    case capital
    case healthcareSpike
    case incomeBonus
    case seasonalShopping
    case travelSpike
}

struct InsightsMonthSummary: Codable, Equatable, Sendable {
    let month: String
    let year: Int
    let monthNumber: Int
    let income: Double
    let expense: Double
    let savings: Double

    var savingsRate: Double {
        guard income > 0 else { return 0 }
        return (income - expense) / income
    }
}

struct InsightsCategoryShare: Codable, Equatable, Sendable, Identifiable {
    var id: String { categoryId }
    let categoryId: String
    let name: String
    let amount: Double
    /// Share of focus-month expenses, 0…100.
    let percentOfExpense: Double
}

struct InsightsMerchantTotal: Codable, Equatable, Sendable, Identifiable {
    let id: String
    /// Display label for the spend (title + date).
    let merchant: String
    let amount: Double
    let percentOfExpense: Double
}

struct InsightsCategoryDelta: Codable, Equatable, Sendable, Identifiable {
    var id: String { categoryId }
    let categoryId: String
    let name: String
    let focusAmount: Double
    let baselineAmount: Double
    /// Percent change vs baseline. Nil when baseline is ~0.
    let percentChange: Double?
    let direction: InsightsChangeDirection
}

enum InsightsChangeDirection: String, Codable, Sendable {
    case up
    case down
    case stable
}

struct InsightsOutlier: Codable, Equatable, Sendable, Identifiable {
    var id: String { "\(title)-\(amount)" }
    let title: String
    let amount: Double
    let categoryName: String?
    let merchant: String?
}

struct InsightsSubscription: Codable, Equatable, Sendable, Identifiable {
    var id: String { name }
    let name: String
    let monthly: Double
}

/// A non-recurring expense the model thinks looks like a loan / EMI / subscription.
struct InsightsPotentialRecurring: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let merchant: String?
    let amount: Double
    let categoryId: String
    let date: Double
    let type: String
    let reason: String
    /// One of: daily, weekly, biweekly, monthly, bimonthly, quarterly.
    let suggestedFrequency: String
    /// Model/heuristic confidence 0–100; only items ≥ 80 are shown.
    let confidencePercent: Int
}

struct InsightsForecast: Codable, Equatable, Sendable {
    let expectedIncome: Double
    let expectedExpense: Double
    let expectedSavings: Double
    let confidence: Double
}

struct InsightsFinancialEvent: Codable, Equatable, Sendable, Identifiable {
    var id: String { "\(kind.rawValue)-\(title)-\(amount)" }
    let kind: InsightsFinancialEventKind
    let title: String
    let amount: Double
    let note: String
    /// When true, exclude from lifestyle / discretionary ratios.
    let excludeFromLifestyle: Bool
}

struct InsightsCategoryBaseline: Codable, Equatable, Sendable, Identifiable {
    var id: String { categoryId }
    let categoryId: String
    let name: String
    let focusAmount: Double
    let rollingAverage: Double
    /// focusAmount / rollingAverage (1.0 = on average).
    let utilization: Double
    let status: InsightsCategoryHealthStatus
}

enum InsightsCategoryHealthStatus: String, Codable, Sendable {
    case withinRange
    case approaching
    case over
    case under
}

/// Compact deterministic payload for UI cards and Foundation Model narratives.
struct InsightsSnapshot: Codable, Equatable, Sendable {
    let focusMonthLabel: String
    let focusYear: Int
    let focusMonth: Int
    let currencySymbol: String
    let months: [InsightsMonthSummary]
    let categoryAllocation: [InsightsCategoryShare]
    let topMerchants: [InsightsMerchantTotal]
    let biggestChanges: [InsightsCategoryDelta]
    let forecast: InsightsForecast
    let outliers: [InsightsOutlier]
    let subscriptions: [InsightsSubscription]
    let potentialRecurring: [InsightsPotentialRecurring]
    let events: [InsightsFinancialEvent]
    let categoryBaselines: [InsightsCategoryBaseline]
    let healthScore: Int
    let healthBreakdown: FinancialHealthBreakdown
    let savingsRate: Double
    let subscriptionShareOfExpense: Double
    let lifestyleExpense: Double
    let contentHash: String

    var hasMeaningfulData: Bool {
        months.contains { $0.expense > 0 || $0.income > 0 }
            || !topMerchants.isEmpty
            || !categoryAllocation.isEmpty
            || !potentialRecurring.isEmpty
    }

    func replacing(potentialRecurring newValue: [InsightsPotentialRecurring]) -> InsightsSnapshot {
        InsightsSnapshot(
            focusMonthLabel: focusMonthLabel,
            focusYear: focusYear,
            focusMonth: focusMonth,
            currencySymbol: currencySymbol,
            months: months,
            categoryAllocation: categoryAllocation,
            topMerchants: topMerchants,
            biggestChanges: biggestChanges,
            forecast: forecast,
            outliers: outliers,
            subscriptions: subscriptions,
            potentialRecurring: newValue,
            events: events,
            categoryBaselines: categoryBaselines,
            healthScore: healthScore,
            healthBreakdown: healthBreakdown,
            savingsRate: savingsRate,
            subscriptionShareOfExpense: subscriptionShareOfExpense,
            lifestyleExpense: lifestyleExpense,
            contentHash: contentHash
        )
    }
}
