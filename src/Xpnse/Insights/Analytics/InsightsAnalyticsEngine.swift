//
//  InsightsAnalyticsEngine.swift
//  Xpnse
//

import Foundation

enum InsightsAnalyticsEngine {
    static let lookbackMonths = 3
    static let topMerchantLimit = 5
    static let topCategoryLimit = 6
    static let biggestChangesLimit = 5

    static func build(
        transactions: [Transaction],
        recurringItems: [RecurringTransaction],
        focusDate: Date = Date(),
        calendar: Calendar = .current,
        currencySymbol: String = CurrencyManager.shared.selectedCurrency.symbol
    ) -> InsightsSnapshot {
        let focusComps = calendar.dateComponents([.year, .month], from: focusDate)
        let focusYear = focusComps.year ?? calendar.component(.year, from: Date())
        let focusMonth = focusComps.month ?? calendar.component(.month, from: Date())

        let monthSummaries = buildMonthSummaries(
            transactions: transactions,
            focusYear: focusYear,
            focusMonth: focusMonth,
            calendar: calendar
        )

        let focusTransactions = transactionsInMonth(
            transactions,
            year: focusYear,
            month: focusMonth,
            calendar: calendar
        )
        let focusExpenses = focusTransactions.filter { $0.type == .expense }
        let focusExpenseTotal = focusExpenses.reduce(0.0) { $0 + $1.totalAmount }

        let categoryAllocation = buildCategoryAllocation(
            expenses: focusExpenses,
            total: focusExpenseTotal
        )

        let topMerchants = buildTopMerchants(
            expenses: focusExpenses,
            total: focusExpenseTotal
        )

        let candidateBaselineMonths = priorMonthKeys(
            focusYear: focusYear,
            focusMonth: focusMonth,
            count: lookbackMonths,
            calendar: calendar
        )
        let baselineMonths = completeMonths(
            among: candidateBaselineMonths,
            transactions: transactions,
            calendar: calendar
        )
        logBaselineMonthSelection(
            candidates: candidateBaselineMonths,
            kept: baselineMonths,
            transactions: transactions,
            calendar: calendar
        )

        let biggestChanges = buildBiggestChanges(
            focusExpenses: focusExpenses,
            transactions: transactions,
            baselineMonths: baselineMonths,
            calendar: calendar
        )

        let categoryBaselines = buildCategoryBaselines(
            focusExpenses: focusExpenses,
            transactions: transactions,
            baselineMonths: baselineMonths,
            focusLabel: monthLabel(year: focusYear, month: focusMonth, calendar: calendar),
            calendar: calendar
        )

        let events = detectEvents(
            transactions: transactions,
            focusExpenses: focusExpenses,
            monthSummaries: monthSummaries,
            focusYear: focusYear,
            focusMonth: focusMonth,
            calendar: calendar
        )

        let lifestyleExpense = max(
            0,
            focusExpenseTotal - events.filter(\.excludeFromLifestyle).reduce(0.0) { $0 + $1.amount }
        )

        let outliers = detectOutliers(expenses: focusExpenses)
        let subscriptions = buildSubscriptions(recurringItems: recurringItems)

        let subscriptionTotal = subscriptions.reduce(0.0) { $0 + $1.monthly }
        let subscriptionShare = focusExpenseTotal > 0 ? subscriptionTotal / focusExpenseTotal : 0

        let forecast = buildForecast(
            focusYear: focusYear,
            focusMonth: focusMonth,
            focusDate: focusDate,
            transactions: transactions,
            recurringItems: recurringItems,
            completeBaselineMonths: baselineMonths,
            calendar: calendar
        )

        let focusSummary = monthSummaries.first {
            $0.year == focusYear && $0.monthNumber == focusMonth
        }
        let savingsRate = focusSummary?.savingsRate ?? 0

        let focusLabel = monthLabel(year: focusYear, month: focusMonth, calendar: calendar)

        var draft = InsightsSnapshot(
            focusMonthLabel: focusLabel,
            focusYear: focusYear,
            focusMonth: focusMonth,
            currencySymbol: currencySymbol,
            months: monthSummaries,
            categoryAllocation: categoryAllocation,
            topMerchants: topMerchants,
            biggestChanges: biggestChanges,
            forecast: forecast,
            outliers: outliers,
            subscriptions: subscriptions,
            events: events,
            categoryBaselines: categoryBaselines,
            healthScore: 3,
            savingsRate: savingsRate,
            subscriptionShareOfExpense: subscriptionShare,
            lifestyleExpense: lifestyleExpense,
            contentHash: ""
        )

        let score = InsightsScoring.score(snapshot: draft)
        draft = InsightsSnapshot(
            focusMonthLabel: draft.focusMonthLabel,
            focusYear: draft.focusYear,
            focusMonth: draft.focusMonth,
            currencySymbol: draft.currencySymbol,
            months: draft.months,
            categoryAllocation: draft.categoryAllocation,
            topMerchants: draft.topMerchants,
            biggestChanges: draft.biggestChanges,
            forecast: draft.forecast,
            outliers: draft.outliers,
            subscriptions: draft.subscriptions,
            events: draft.events,
            categoryBaselines: draft.categoryBaselines,
            healthScore: score,
            savingsRate: draft.savingsRate,
            subscriptionShareOfExpense: draft.subscriptionShareOfExpense,
            lifestyleExpense: draft.lifestyleExpense,
            contentHash: contentHash(for: draft)
        )
        return draft
    }

    // MARK: - Months

    private static func buildMonthSummaries(
        transactions: [Transaction],
        focusYear: Int,
        focusMonth: Int,
        calendar: Calendar
    ) -> [InsightsMonthSummary] {
        let priorCandidates = priorMonthKeys(
            focusYear: focusYear,
            focusMonth: focusMonth,
            count: lookbackMonths,
            calendar: calendar
        )
        let completePrior = completeMonths(
            among: priorCandidates,
            transactions: transactions,
            calendar: calendar
        )
        let keys = completePrior + [(focusYear, focusMonth)]

        return keys.map { year, month in
            let monthTxns = transactionsInMonth(transactions, year: year, month: month, calendar: calendar)
            let income = monthTxns.filter { $0.type == .income }.reduce(0.0) { $0 + $1.totalAmount }
            let expense = monthTxns.filter { $0.type == .expense }.reduce(0.0) { $0 + $1.totalAmount }
            let savings = income - expense
            return InsightsMonthSummary(
                month: ExpenseTrendMonthPalette.shortLabel(forMonth: month, calendar: calendar),
                year: year,
                monthNumber: month,
                income: income,
                expense: expense,
                savings: savings
            )
        }
    }

    // MARK: - Categories / merchants

    private static func buildCategoryAllocation(
        expenses: [Transaction],
        total: Double
    ) -> [InsightsCategoryShare] {
        let grouped = Dictionary(grouping: expenses) {
            CategoryStore.shared.canonicalCategoryId(for: $0.categoryId)
        }
        return grouped
            .map { id, txns -> InsightsCategoryShare in
                let amount = txns.reduce(0.0) { $0 + $1.totalAmount }
                let percent = total > 0 ? (amount / total) * 100 : 0
                return InsightsCategoryShare(
                    categoryId: id,
                    name: CategoryStore.shared.categoryDisplayName(for: id),
                    amount: amount,
                    percentOfExpense: percent
                )
            }
            .sorted { $0.amount > $1.amount }
            .prefix(topCategoryLimit)
            .map { $0 }
    }

    private static func buildTopMerchants(
        expenses: [Transaction],
        total: Double
    ) -> [InsightsMerchantTotal] {
        let resolver = MerchantDisplayResolver(expenses: expenses)
        var totals: [String: Double] = [:]
        for expense in expenses {
            let key = resolver.key(for: expense)
            guard !key.isEmpty else { continue }
            totals[key, default: 0] += expense.totalAmount
        }
        return totals
            .map { name, amount in
                InsightsMerchantTotal(
                    merchant: name,
                    amount: amount,
                    percentOfExpense: total > 0 ? (amount / total) * 100 : 0
                )
            }
            .sorted { $0.amount > $1.amount }
            .prefix(topMerchantLimit)
            .map { $0 }
    }

    /// Groups payees so title-only rows (e.g. "Car loan") merge into the merchant
    /// used on sibling transactions / the same recurring series (e.g. "Kotak Mahindra Bank").
    private struct MerchantDisplayResolver {
        private let merchantBySeriesId: [String: String]
        private let merchantByNormalizedTitle: [String: String]

        init(expenses: [Transaction]) {
            var seriesMap: [String: String] = [:]
            var titleMerchants: [String: Set<String>] = [:]

            for expense in expenses {
                let merchant = Self.normalizedMerchant(expense.merchant)
                let titleKey = SuggestionEngine.normalize(expense.title)

                if let merchant {
                    if let seriesId = expense.recurringSeriesId, seriesMap[seriesId] == nil {
                        seriesMap[seriesId] = merchant
                    }
                    if !titleKey.isEmpty {
                        titleMerchants[titleKey, default: []].insert(merchant)
                    }
                }
            }

            // Only remap a title → merchant when that title consistently maps to one merchant.
            var titleMap: [String: String] = [:]
            for (title, merchants) in titleMerchants where merchants.count == 1 {
                titleMap[title] = merchants.first!
            }

            self.merchantBySeriesId = seriesMap
            self.merchantByNormalizedTitle = titleMap
        }

        func key(for transaction: Transaction) -> String {
            if let merchant = Self.normalizedMerchant(transaction.merchant) {
                return merchant
            }
            if let seriesId = transaction.recurringSeriesId,
               let merchant = merchantBySeriesId[seriesId] {
                return merchant
            }
            let titleKey = SuggestionEngine.normalize(transaction.title)
            if let merchant = merchantByNormalizedTitle[titleKey] {
                return merchant
            }
            let description = transaction.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { return "Unknown" }
            return "Unknown (\(description))"
        }

        private static func normalizedMerchant(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty
            else { return nil }
            return trimmed
        }
    }

    private static func buildBiggestChanges(
        focusExpenses: [Transaction],
        transactions: [Transaction],
        baselineMonths: [(Int, Int)],
        calendar: Calendar
    ) -> [InsightsCategoryDelta] {
        let focusByCategory = amountsByCategory(focusExpenses)
        let baselineTxns = baselineMonths.flatMap {
            transactionsInMonth(transactions, year: $0.0, month: $0.1, calendar: calendar)
                .filter { $0.type == .expense }
        }
        let baselineTotals = amountsByCategory(baselineTxns)
        let divisor = Double(max(baselineMonths.count, 1))

        let allIds = Set(focusByCategory.keys).union(baselineTotals.keys)
        return allIds.compactMap { id -> InsightsCategoryDelta? in
            let focus = focusByCategory[id] ?? 0
            let baselineAvg = (baselineTotals[id] ?? 0) / divisor
            guard focus > 0 || baselineAvg > 0 else { return nil }
            let percent: Double? = baselineAvg > 0.01 ? ((focus - baselineAvg) / baselineAvg) * 100 : nil
            let direction = FinancialHealthRules.changeDirection(percentChange: percent)
            return InsightsCategoryDelta(
                categoryId: id,
                name: CategoryStore.shared.categoryDisplayName(for: id),
                focusAmount: focus,
                baselineAmount: baselineAvg,
                percentChange: percent,
                direction: direction
            )
        }
        .sorted { abs($0.percentChange ?? 0) > abs($1.percentChange ?? 0) }
        .prefix(biggestChangesLimit)
        .map { $0 }
    }

    private static func buildCategoryBaselines(
        focusExpenses: [Transaction],
        transactions: [Transaction],
        baselineMonths: [(Int, Int)],
        focusLabel: String,
        calendar: Calendar
    ) -> [InsightsCategoryBaseline] {
        let focusByCategory = amountsByCategory(focusExpenses)
        let divisor = Double(max(baselineMonths.count, 1))

        let perMonthByCategory: [String: [(month: String, amount: Double)]] = {
            var map: [String: [(month: String, amount: Double)]] = [:]
            for (year, month) in baselineMonths {
                let key = "\(year)-\(month)"
                let expenses = transactionsInMonth(transactions, year: year, month: month, calendar: calendar)
                    .filter { $0.type == .expense }
                let amounts = amountsByCategory(expenses)
                let ids = Set(focusByCategory.keys).union(amounts.keys)
                for id in ids {
                    map[id, default: []].append((month: key, amount: amounts[id] ?? 0))
                }
            }
            return map
        }()

        let baselines = focusByCategory
            .map { id, focus -> InsightsCategoryBaseline in
                let perMonth = perMonthByCategory[id] ?? baselineMonths.map {
                    (month: "\($0.0)-\($0.1)", amount: 0.0)
                }
                let sum = perMonth.reduce(0.0) { $0 + $1.amount }
                let avg = sum / divisor
                // No history in lookback → treat as 200% so the row surfaces as elevated, not "on track".
                let utilization = avg > 0.01 ? focus / avg : (focus > 0 ? 2.0 : 1.0)
                let status = FinancialHealthRules.categoryStatus(utilization: utilization)
                return InsightsCategoryBaseline(
                    categoryId: id,
                    name: CategoryStore.shared.categoryDisplayName(for: id),
                    focusAmount: focus,
                    rollingAverage: avg,
                    utilization: utilization,
                    status: status
                )
            }
            .sorted { $0.focusAmount > $1.focusAmount }
            .prefix(topCategoryLimit)
            .map { $0 }

        InsightsCalculationLog.categoryBaselines(
            focusLabel: focusLabel,
            baselineMonths: baselineMonths,
            rows: baselines.map { item in
                let perMonth = perMonthByCategory[item.categoryId] ?? []
                return InsightsCalculationLog.CategoryBaselineCalcRow(
                    name: item.name,
                    focusAmount: item.focusAmount,
                    perMonthAmounts: perMonth,
                    baselineSum: perMonth.reduce(0.0) { $0 + $1.amount },
                    rollingAverage: item.rollingAverage,
                    utilization: item.utilization,
                    status: item.status
                )
            }
        )

        return baselines
    }

    private static func logBaselineMonthSelection(
        candidates: [(Int, Int)],
        kept: [(Int, Int)],
        transactions: [Transaction],
        calendar: Calendar
    ) {
        let keptSet = Set(kept.map { "\($0.0)-\($0.1)" })
        let volumes: [(key: String, volume: Double, kept: Bool)] = candidates.map { year, month in
            let key = "\(year)-\(month)"
            let volume = monthDataVolume(
                transactions: transactions,
                year: year,
                month: month,
                calendar: calendar
            )
            return (key: key, volume: volume, kept: keptSet.contains(key))
        }
        InsightsCalculationLog.baselineMonths(
            candidates: candidates,
            kept: kept,
            volumes: volumes
        )
    }

    // MARK: - Events / outliers / subscriptions

    /// Surfaces rare, event-like spends (festival shopping, annual insurance) — not recurring
    /// materializations or mild category bumps already covered by Category health.
    private static func detectEvents(
        transactions: [Transaction],
        focusExpenses: [Transaction],
        monthSummaries: [InsightsMonthSummary],
        focusYear: Int,
        focusMonth: Int,
        calendar: Calendar
    ) -> [InsightsFinancialEvent] {
        let discretionaryFocus = focusExpenses.filter { !$0.isRecurringGenerated }
        var events: [InsightsFinancialEvent] = []

        let historyByCategoryMonth = categoryMonthTotals(
            transactions: transactions.filter { $0.type == .expense && !$0.isRecurringGenerated },
            calendar: calendar
        )

        // 1) Category-month spikes vs that category's history (primary signal).
        let focusByCategory = amountsByCategory(discretionaryFocus)
        var spikedCategoryIds = Set<String>()
        for (categoryId, focusTotal) in focusByCategory {
            guard focusTotal >= FinancialHealthRules.eventCategoryAbsoluteFloor else { continue }

            let priorTotals = historyByCategoryMonth
                .filter { $0.categoryId == categoryId && !($0.year == focusYear && $0.month == focusMonth) }
                .map(\.amount)
            let name = CategoryStore.shared.categoryDisplayName(for: categoryId)

            guard isRareCategoryMonthSpike(focusTotal: focusTotal, priorMonthlyTotals: priorTotals) else {
                continue
            }

            spikedCategoryIds.insert(categoryId)
            let avg = priorTotals.isEmpty
                ? 0
                : priorTotals.reduce(0, +) / Double(priorTotals.count)
            let kind = eventKind(forCategoryId: categoryId, titleHints: discretionaryFocus
                .filter { CategoryStore.shared.canonicalCategoryId(for: $0.categoryId) == categoryId }
                .map(\.title))
            let multipleText: String = {
                guard avg > 0.01 else { return "unusual for this category" }
                let multiple = focusTotal / avg
                return String(format: "%.1f× your typical %@ month", multiple, name.lowercased())
            }()

            events.append(
                InsightsFinancialEvent(
                    kind: kind,
                    title: "\(name) spike",
                    amount: focusTotal,
                    note: "Rare high spend this month — \(multipleText).",
                    excludeFromLifestyle: shouldExcludeFromLifestyle(kind: kind)
                )
            )
        }

        // 2) Individual annual / festival-style one-offs (non-recurring only).
        let focusPeerAmounts = Dictionary(grouping: discretionaryFocus) {
            CategoryStore.shared.canonicalCategoryId(for: $0.categoryId)
        }.mapValues { $0.map(\.totalAmount).sorted() }

        let historicalTxnAmountsByCategory: [String: [Double]] = {
            var map: [String: [Double]] = [:]
            for tx in transactions where tx.type == .expense && !tx.isRecurringGenerated {
                let date = Date(timeIntervalSince1970: tx.date)
                let comps = calendar.dateComponents([.year, .month], from: date)
                guard let year = comps.year, let month = comps.month else { continue }
                if year == focusYear && month == focusMonth { continue }
                let id = CategoryStore.shared.canonicalCategoryId(for: tx.categoryId)
                map[id, default: []].append(tx.totalAmount)
            }
            return map.mapValues { $0.sorted() }
        }()

        for expense in discretionaryFocus {
            let amount = expense.totalAmount
            let categoryId = CategoryStore.shared.canonicalCategoryId(for: expense.categoryId)
            // Category-month spike already explains this category.
            if spikedCategoryIds.contains(categoryId) { continue }

            let focusPeers = focusPeerAmounts[categoryId] ?? []
            let historyPeers = historicalTxnAmountsByCategory[categoryId] ?? []
            let referencePeers = historyPeers.count >= 2 ? historyPeers : focusPeers
            let categoryMedian = medianValue(referencePeers)
            let hasEventCue = looksLikeAnnualOrFestivalEvent(title: expense.title, merchant: expense.merchant)

            let rareVsHistory = categoryMedian > 0.01
                && amount >= max(
                    FinancialHealthRules.eventTxnAbsoluteFloor,
                    categoryMedian * FinancialHealthRules.eventTxnMultipleOfCategoryMedian
                )
            // Keyword cues (insurance, festival, …) with a meaningful floor — even if it's the only peer.
            let cueAndMeaningful = hasEventCue
                && amount >= FinancialHealthRules.eventTxnAbsoluteFloor

            guard rareVsHistory || cueAndMeaningful else { continue }

            let kind = eventKind(forCategoryId: categoryId, titleHints: [expense.title])
            let label = expense.merchant?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? expense.title
            events.append(
                InsightsFinancialEvent(
                    kind: kind,
                    title: label,
                    amount: amount,
                    note: hasEventCue
                        ? "Looks like a one-time / annual-style expense."
                        : "Unusually large vs other \(CategoryStore.shared.categoryDisplayName(for: categoryId).lowercased()) spends.",
                    excludeFromLifestyle: shouldExcludeFromLifestyle(kind: kind)
                        || (categoryMedian > 0 && amount >= categoryMedian * 6)
                )
            )
        }

        if let focus = monthSummaries.first(where: { $0.year == focusYear && $0.monthNumber == focusMonth }) {
            let priorIncomes = monthSummaries
                .filter { !($0.year == focusYear && $0.monthNumber == focusMonth) }
                .map(\.income)
                .filter { $0 > 0 }
            let avgIncome = priorIncomes.isEmpty
                ? 0
                : priorIncomes.reduce(0, +) / Double(priorIncomes.count)
            if avgIncome > 0, focus.income >= avgIncome * FinancialHealthRules.incomeBonusMultiple {
                events.append(
                    InsightsFinancialEvent(
                        kind: .incomeBonus,
                        title: "Elevated income",
                        amount: focus.income,
                        note: "Income unusually high vs recent average — treat savings ratio carefully.",
                        excludeFromLifestyle: false
                    )
                )
            }
        }

        var seen = Set<String>()
        let deduped = events.filter { event in
            let key = "\(event.kind.rawValue)|\(event.title)|\(Int(event.amount))"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        .sorted { $0.amount > $1.amount }

        InsightsCalculationLog.detectedEvents(
            focus: "\(focusYear)-\(focusMonth)",
            discretionaryCount: discretionaryFocus.count,
            recurringExcluded: focusExpenses.count - discretionaryFocus.count,
            events: deduped.map {
                "\($0.kind.rawValue)|\($0.title)|\(String(format: "%.2f", $0.amount))|\($0.note)"
            }
        )

        return deduped
    }

    private static func isRareCategoryMonthSpike(
        focusTotal: Double,
        priorMonthlyTotals: [Double]
    ) -> Bool {
        let nonZeroPriors = priorMonthlyTotals.filter { $0 > 0.01 }
        // First meaningful month in a category — only flag if clearly large with event cues handled elsewhere.
        guard !nonZeroPriors.isEmpty else { return false }

        let avg = nonZeroPriors.reduce(0, +) / Double(nonZeroPriors.count)
        let priorMax = nonZeroPriors.max() ?? 0

        let vsAverage = avg > 0.01
            && focusTotal >= avg * FinancialHealthRules.eventCategorySpikeMultipleOfAverage
        let vsPriorMax = priorMax > 0.01
            && focusTotal >= priorMax * FinancialHealthRules.eventCategorySpikeMultipleOfPriorMax

        // Require a clear jump — mild 20–50% bumps belong in Category health, not events.
        return vsAverage || vsPriorMax
    }

    private static func categoryMonthTotals(
        transactions: [Transaction],
        calendar: Calendar
    ) -> [(categoryId: String, year: Int, month: Int, amount: Double)] {
        var buckets: [String: Double] = [:]
        for tx in transactions {
            let date = Date(timeIntervalSince1970: tx.date)
            let comps = calendar.dateComponents([.year, .month], from: date)
            guard let year = comps.year, let month = comps.month else { continue }
            let categoryId = CategoryStore.shared.canonicalCategoryId(for: tx.categoryId)
            let key = "\(categoryId)|\(year)|\(month)"
            buckets[key, default: 0] += tx.totalAmount
        }
        return buckets.compactMap { key, amount in
            let parts = key.split(separator: "|")
            guard parts.count == 3,
                  let year = Int(parts[1]),
                  let month = Int(parts[2]) else { return nil }
            return (categoryId: String(parts[0]), year: year, month: month, amount: amount)
        }
    }

    private static func looksLikeAnnualOrFestivalEvent(title: String, merchant: String?) -> Bool {
        let haystack = [title, merchant ?? ""]
            .joined(separator: " ")
            .lowercased()
        let cues = [
            "insurance", "premium", "renewal", "annual", "yearly", "festival",
            "diwali", "deepavali", "christmas", "thanksgiving", "eid", "wedding",
            "honeymoon", "vacation", "holiday", "registration", "tax",
            "down payment", "downpayment", "gift"
        ]
        return cues.contains { haystack.contains($0) }
    }

    private static func eventKind(
        forCategoryId categoryId: String,
        titleHints: [String]
    ) -> InsightsFinancialEventKind {
        let joined = titleHints.joined(separator: " ").lowercased()
        if categoryId == "health" || joined.contains("hospital") || joined.contains("medical") {
            return .healthcareSpike
        }
        if categoryId.contains("home")
            || joined.contains("construction")
            || joined.contains("appliance") {
            return .capital
        }
        if categoryId == "transport"
            || joined.contains("travel")
            || joined.contains("flight")
            || joined.contains("hotel") {
            return .travelSpike
        }
        if categoryId == "shopping"
            || joined.contains("festival")
            || joined.contains("diwali")
            || joined.contains("christmas") {
            return .seasonalShopping
        }
        return .oneTimeLarge
    }

    private static func shouldExcludeFromLifestyle(kind: InsightsFinancialEventKind) -> Bool {
        switch kind {
        case .healthcareSpike, .capital, .travelSpike, .oneTimeLarge:
            return true
        case .seasonalShopping, .incomeBonus:
            return false
        }
    }

    private static func detectOutliers(expenses: [Transaction]) -> [InsightsOutlier] {
        // Outlier list stays for analytics internals; UI events use detectEvents.
        let discretionary = expenses.filter { !$0.isRecurringGenerated }
        let amounts = discretionary.map(\.totalAmount).sorted()
        let median = medianValue(amounts)
        let threshold = max(
            FinancialHealthRules.eventTxnAbsoluteFloor,
            median * FinancialHealthRules.eventTxnMultipleOfCategoryMedian
        )
        return discretionary
            .filter { $0.totalAmount >= threshold }
            .sorted { $0.totalAmount > $1.totalAmount }
            .prefix(5)
            .map {
                InsightsOutlier(
                    title: $0.title,
                    amount: $0.totalAmount,
                    categoryName: $0.categoryDisplayName,
                    merchant: $0.merchant
                )
            }
    }

    private static func buildSubscriptions(recurringItems: [RecurringTransaction]) -> [InsightsSubscription] {
        recurringItems
            .filter { $0.state == .active && $0.type == TransactionType.expense.rawValue }
            .map { item in
                let monthly = approximateMonthlyAmount(item)
                let name = item.merchant?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? item.title
                return InsightsSubscription(name: name, monthly: monthly)
            }
            .sorted { $0.monthly > $1.monthly }
            .prefix(8)
            .map { $0 }
    }

    private static func approximateMonthlyAmount(_ item: RecurringTransaction) -> Double {
        let amount = NSDecimalNumber(decimal: item.amount).doubleValue
        switch item.recurrence {
        case .daily:
            return amount * 30
        case .weeklyOn:
            return amount * 4.3
        case .everyTwoWeeksOn:
            return amount * 2.15
        case .everyThreeWeeksOn:
            return amount * (30.0 / 21.0)
        case .everyFourWeeksOn:
            return amount * (30.0 / 28.0)
        case .monthlyOn:
            return amount
        case .onceInEveryTwoMonthsOn:
            return amount / 2
        case .onceInEveryQuarterOn:
            return amount / 3
        }
    }

    // MARK: - Forecast

    private static func buildForecast(
        focusYear: Int,
        focusMonth: Int,
        focusDate: Date,
        transactions: [Transaction],
        recurringItems: [RecurringTransaction],
        completeBaselineMonths: [(Int, Int)],
        calendar: Calendar
    ) -> InsightsForecast {
        let day = calendar.component(.day, from: focusDate)
        let expenses = transactions.filter { $0.type == .expense }
        let allowedKeys = Set(completeBaselineMonths.map { monthKey(year: $0.0, month: $0.1) })
        let extrapolation = MonthExpenseExtrapolationEngine.extrapolateRemainingDays(
            year: focusYear,
            month: focusMonth,
            asOfDay: day,
            historicalExpenses: expenses,
            recurringItems: recurringItems,
            lookbackMonths: lookbackMonths,
            allowedLookbackMonthKeys: allowedKeys,
            calendar: calendar
        )

        let monthToDateExpense = transactionsInMonth(
            transactions,
            year: focusYear,
            month: focusMonth,
            calendar: calendar
        )
        .filter { $0.type == .expense }
        .reduce(0.0) { $0 + $1.totalAmount }

        let projectedRemainder = extrapolation.dailyAmounts.reduce(0.0) { $0 + $1.total }
        let expectedExpense = monthToDateExpense + projectedRemainder

        let priorIncomes = completeBaselineMonths.map { year, month in
            transactionsInMonth(transactions, year: year, month: month, calendar: calendar)
                .filter { $0.type == .income }
                .reduce(0.0) { $0 + $1.totalAmount }
        }.filter { $0 > 0 }

        let avgIncome = priorIncomes.isEmpty
            ? transactionsInMonth(transactions, year: focusYear, month: focusMonth, calendar: calendar)
                .filter { $0.type == .income }
                .reduce(0.0) { $0 + $1.totalAmount }
            : priorIncomes.reduce(0, +) / Double(priorIncomes.count)

        let recurringIncomeMonthly = recurringItems
            .filter { $0.state == .active && $0.type == TransactionType.income.rawValue }
            .reduce(0.0) { $0 + approximateMonthlyAmount($1) }

        let expectedIncome = max(avgIncome, recurringIncomeMonthly)
        let expectedSavings = expectedIncome - expectedExpense

        let expenseHistory = completeBaselineMonths.map { year, month in
            transactionsInMonth(transactions, year: year, month: month, calendar: calendar)
                .filter { $0.type == .expense }
                .reduce(0.0) { $0 + $1.totalAmount }
        }.filter { $0 > 0 }

        let confidence: Double = {
            guard expenseHistory.count >= 2 else { return expenseHistory.isEmpty ? 0.45 : 0.55 }
            let mean = expenseHistory.reduce(0, +) / Double(expenseHistory.count)
            guard mean > 0 else { return 0.5 }
            let variance = expenseHistory.map { pow($0 - mean, 2) }.reduce(0, +) / Double(expenseHistory.count)
            let cv = sqrt(variance) / mean
            return min(0.95, max(0.45, 1.0 - cv))
        }()

        return InsightsForecast(
            expectedIncome: expectedIncome,
            expectedExpense: expectedExpense,
            expectedSavings: expectedSavings,
            confidence: confidence
        )
    }

    // MARK: - Completeness

    /// Keeps lookback months whose data volume is at least 70% of peer months in the same window.
    /// Sparse / partially logged months are excluded so they cannot skew baselines.
    static func completeMonths(
        among candidates: [(Int, Int)],
        transactions: [Transaction],
        calendar: Calendar
    ) -> [(Int, Int)] {
        guard !candidates.isEmpty else { return [] }

        let volumes: [(key: (Int, Int), volume: Double)] = candidates.map { year, month in
            let volume = monthDataVolume(
                transactions: transactions,
                year: year,
                month: month,
                calendar: calendar
            )
            return ((year, month), volume)
        }

        return volumes.compactMap { entry in
            let peers = volumes
                .filter { $0.key != entry.key && $0.volume > 0 }
                .map(\.volume)

            if peers.isEmpty {
                return entry.volume > 0 ? entry.key : nil
            }

            let reference = medianValue(peers)
            guard reference > 0 else {
                return entry.volume > 0 ? entry.key : nil
            }

            let ratio = entry.volume / reference
            return ratio >= FinancialHealthRules.monthCompletenessMinimumRatio ? entry.key : nil
        }
    }

    /// Combines spend volume and active-day coverage so thinly logged months score lower.
    private static func monthDataVolume(
        transactions: [Transaction],
        year: Int,
        month: Int,
        calendar: Calendar
    ) -> Double {
        let monthTxns = transactionsInMonth(transactions, year: year, month: month, calendar: calendar)
        let expenses = monthTxns.filter { $0.type == .expense }
        let expenseTotal = expenses.reduce(0.0) { $0 + $1.totalAmount }
        let expenseCount = Double(expenses.count)

        let daysInMonth = Double(
            MonthExpenseExtrapolationEngine.daysInMonth(month: month, year: year, calendar: calendar)
        )
        let activeDays = Set(
            monthTxns.map { calendar.component(.day, from: Date(timeIntervalSince1970: $0.date)) }
        ).count
        let dayCoverage = daysInMonth > 0 ? Double(activeDays) / daysInMonth : 0

        // Weight amount most, with activity density so a few large txs in an otherwise empty month
        // still don't look "complete" versus well-logged peers.
        return expenseTotal * (0.35 + 0.65 * min(1.0, dayCoverage * 2.0)) + expenseCount
    }

    static func monthKey(year: Int, month: Int) -> String {
        "\(year)-\(month)"
    }

    // MARK: - Helpers

    private static func transactionsInMonth(
        _ transactions: [Transaction],
        year: Int,
        month: Int,
        calendar: Calendar
    ) -> [Transaction] {
        transactions.filter { txn in
            let date = Date(timeIntervalSince1970: txn.date)
            let comps = calendar.dateComponents([.year, .month], from: date)
            return comps.year == year && comps.month == month
        }
    }

    private static func priorMonthKeys(
        focusYear: Int,
        focusMonth: Int,
        count: Int,
        calendar: Calendar
    ) -> [(Int, Int)] {
        guard let focus = calendar.date(from: DateComponents(year: focusYear, month: focusMonth, day: 1))
        else { return [] }
        return (1...count).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: focus) else { return nil }
            let comps = calendar.dateComponents([.year, .month], from: date)
            guard let y = comps.year, let m = comps.month else { return nil }
            return (y, m)
        }.reversed()
    }

    private static func amountsByCategory(_ expenses: [Transaction]) -> [String: Double] {
        var map: [String: Double] = [:]
        for expense in expenses {
            let id = CategoryStore.shared.canonicalCategoryId(for: expense.categoryId)
            map[id, default: 0] += expense.totalAmount
        }
        return map
    }

    private static func medianValue(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    private static func monthLabel(year: Int, month: Int, calendar: Calendar) -> String {
        let short = ExpenseTrendMonthPalette.shortLabel(forMonth: month, calendar: calendar)
        return "\(short) \(year)"
    }

    private static func contentHash(for snapshot: InsightsSnapshot) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = InsightsSnapshot(
            focusMonthLabel: snapshot.focusMonthLabel,
            focusYear: snapshot.focusYear,
            focusMonth: snapshot.focusMonth,
            currencySymbol: snapshot.currencySymbol,
            months: snapshot.months,
            categoryAllocation: snapshot.categoryAllocation,
            topMerchants: snapshot.topMerchants,
            biggestChanges: snapshot.biggestChanges,
            forecast: snapshot.forecast,
            outliers: snapshot.outliers,
            subscriptions: snapshot.subscriptions,
            events: snapshot.events,
            categoryBaselines: snapshot.categoryBaselines,
            healthScore: snapshot.healthScore,
            savingsRate: snapshot.savingsRate,
            subscriptionShareOfExpense: snapshot.subscriptionShareOfExpense,
            lifestyleExpense: snapshot.lifestyleExpense,
            contentHash: ""
        )
        guard let data = try? encoder.encode(payload) else { return UUID().uuidString }
        return String(data.base64EncodedString().prefix(64))
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
