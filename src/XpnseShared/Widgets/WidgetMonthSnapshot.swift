//
//  WidgetMonthSnapshot.swift
//  Xpnse
//

import Foundation

struct WidgetMonthSnapshot: Codable {
    let periodLabel: String
    let totalBalance: Double
    let totalIncome: Double
    let totalExpenses: Double
    let totalSavings: Double
    let currencySymbol: String
    let donutSlices: [WidgetDonutSlice]
    /// Financial overview legend slices (expense, savings, balance).
    let expenseCategories: [WidgetDonutSlice]
    let donutCenterTitle: String
    let donutCenterAmount: Double
    let updatedAt: Date

    init(
        periodLabel: String,
        totalBalance: Double,
        totalIncome: Double,
        totalExpenses: Double,
        totalSavings: Double,
        currencySymbol: String,
        donutSlices: [WidgetDonutSlice],
        expenseCategories: [WidgetDonutSlice],
        donutCenterTitle: String,
        donutCenterAmount: Double,
        updatedAt: Date
    ) {
        self.periodLabel = periodLabel
        self.totalBalance = totalBalance
        self.totalIncome = totalIncome
        self.totalExpenses = totalExpenses
        self.totalSavings = totalSavings
        self.currencySymbol = currencySymbol
        self.donutSlices = donutSlices
        self.expenseCategories = expenseCategories
        self.donutCenterTitle = donutCenterTitle
        self.donutCenterAmount = donutCenterAmount
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        periodLabel = try container.decode(String.self, forKey: .periodLabel)
        totalBalance = try container.decode(Double.self, forKey: .totalBalance)
        totalIncome = try container.decode(Double.self, forKey: .totalIncome)
        totalExpenses = try container.decode(Double.self, forKey: .totalExpenses)
        totalSavings = try container.decodeIfPresent(Double.self, forKey: .totalSavings) ?? 0
        currencySymbol = try container.decode(String.self, forKey: .currencySymbol)
        donutSlices = try container.decode([WidgetDonutSlice].self, forKey: .donutSlices)
        donutCenterTitle = try container.decode(String.self, forKey: .donutCenterTitle)
        donutCenterAmount = try container.decode(Double.self, forKey: .donutCenterAmount)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        if let categories = try container.decodeIfPresent([WidgetDonutSlice].self, forKey: .expenseCategories) {
            expenseCategories = categories
        } else {
            expenseCategories = donutSlices
                .filter { !$0.isRemainder }
                .sorted { $0.amount > $1.amount }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(periodLabel, forKey: .periodLabel)
        try container.encode(totalBalance, forKey: .totalBalance)
        try container.encode(totalIncome, forKey: .totalIncome)
        try container.encode(totalExpenses, forKey: .totalExpenses)
        try container.encode(totalSavings, forKey: .totalSavings)
        try container.encode(currencySymbol, forKey: .currencySymbol)
        try container.encode(donutSlices, forKey: .donutSlices)
        try container.encode(expenseCategories, forKey: .expenseCategories)
        try container.encode(donutCenterTitle, forKey: .donutCenterTitle)
        try container.encode(donutCenterAmount, forKey: .donutCenterAmount)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case periodLabel
        case totalBalance
        case totalIncome
        case totalExpenses
        case totalSavings
        case currencySymbol
        case donutSlices
        case expenseCategories
        case donutCenterTitle
        case donutCenterAmount
        case updatedAt
    }

    static let empty = WidgetMonthSnapshot(
        periodLabel: "",
        totalBalance: 0,
        totalIncome: 0,
        totalExpenses: 0,
        totalSavings: 0,
        currencySymbol: "$",
        donutSlices: [],
        expenseCategories: [],
        donutCenterTitle: "Balance",
        donutCenterAmount: 0,
        updatedAt: .distantPast
    )
}

struct WidgetDonutSlice: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let amount: Double
    let colorHex: String
    let isRemainder: Bool
}
