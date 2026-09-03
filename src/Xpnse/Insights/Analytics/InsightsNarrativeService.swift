//
//  InsightsNarrativeService.swift
//  Xpnse
//

import Foundation
import FoundationModels

@Generable
struct InsightsNarrativeResult {
    @Guide(description: "1-3 sentences in second person (you/your) about the current focus period only (use focusMonthLabel). Cover where you stand now, why it matters, and a gentle next step. For savings vs the 20–30% guide, paste healthBreakdown.savingsRateAssessment verbatim — never invent above/below/strong. Never mention prior periods or say 'the user'.")
    var healthSummary: String

    @Guide(description: "Short second-person spending personality label, e.g. 'Planned spender' or 'You seem like a steady saver'. Never 'the user'.")
    var personalityLabel: String

    @Guide(description: "1-2 sentences in second person explaining the personality label using only snapshot facts. Start with 'You' where natural.")
    var personalityBlurb: String

    @Guide(description: "One line in second person about top spends. Empty if none. Use you/your, not the user.")
    var merchantGloss: String

    @Guide(description: "Up to 3 second-person opportunity lines (you could…). Include approximate savings when numbers exist.")
    var opportunities: [String]

    @Guide(description: "Up to 3 second-person win lines celebrating real progress (you've…, your…).")
    var wins: [String]
}

struct InsightsNarratives: Equatable, Sendable {
    var healthSummary: String
    var personalityLabel: String
    var personalityBlurb: String
    var merchantGloss: String
    var opportunities: [String]
    var wins: [String]

    static let empty = InsightsNarratives(
        healthSummary: "",
        personalityLabel: "",
        personalityBlurb: "",
        merchantGloss: "",
        opportunities: [],
        wins: []
    )

    var hasContent: Bool {
        !healthSummary.isEmpty
            || !personalityBlurb.isEmpty
            || !opportunities.isEmpty
            || !wins.isEmpty
    }
}

@MainActor
final class InsightsNarrativeService {
    private var task: Task<InsightsNarratives, Never>?
    private var memoryCache: [String: InsightsNarratives] = [:]

    private var cacheURL: URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let lang = L10n.preferredLanguageCode
        return base.appendingPathComponent("insights-narrative-cache-v6-\(lang).json")
    }

    func narratives(
        for snapshot: InsightsSnapshot,
        focusExpenses: [Transaction] = []
    ) async -> (InsightsNarratives, wasFreshlyGenerated: Bool) {
        let key = "\(snapshot.contentHash)|\(L10n.preferredLanguageCode)"
        if InsightsResultCache.Policy.narrativeReadsEnabled {
            if let cached = memoryCache[key] {
                return (cached, false)
            }
            if let disk = loadDiskCache()[key] {
                memoryCache[key] = disk
                return (disk, false)
            }
        }

        guard FoundationModelsAvailability.isAvailable else {
            return (.empty, false)
        }

        task?.cancel()
        let work = Task<InsightsNarratives, Never> { @MainActor in
            await self.generate(snapshot: snapshot, focusExpenses: focusExpenses)
        }
        task = work
        let result = await work.value
        if result.hasContent {
            memoryCache[key] = result
            if memoryCache.count > 12 {
                memoryCache = Dictionary(uniqueKeysWithValues: memoryCache.suffix(12))
            }
            persist(key: key, value: result)
            return (result, true)
        }
        return (result, false)
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func generate(
        snapshot: InsightsSnapshot,
        focusExpenses: [Transaction],
        slim: Bool = false
    ) async -> InsightsNarratives {
        guard !Task.isCancelled else { return .empty }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(
            NarrativeModelSnapshot(from: snapshot, focusExpenses: focusExpenses, slim: slim)
        ),
              let json = String(data: data, encoding: .utf8)
        else { return .empty }

        let languageName = L10n.preferredLanguageNameForPrompts
        let languageCode = L10n.preferredLanguageCode
        let prompt = """
        You are a concise on-device financial coach for SnapLedger, speaking directly to the person reading.
        Language (mandatory): Write ALL user-facing output (healthSummary, personalityLabel, personalityBlurb, merchantGloss, opportunities, wins) in \(languageName) (BCP-47: \(languageCode)). Do not mix languages.
        Voice rules (mandatory):
        - Always use second person appropriate for \(languageName).
        - Never write "the user", "user", or third-person observations about the reader.
        Use ONLY the JSON facts below. Do not invent amounts, merchants, or categories.
        The financial health star rating is already computed in `healthBreakdown.finalStars` and `healthBreakdown.totalScore`.
        Do NOT change or recalculate the score. Explain it using `healthBreakdown.reasons`.
        For savings rate, use `healthBreakdown.savingsRateAssessment` verbatim — it already states whether the rate is below, within, or above the guide.
        Never invert comparisons: 19% is below 20–30% (not strong/above); 38% is above 20–30% (not below).
        Do not paraphrase the savings-rate comparison in your own words if you might get the direction wrong — paste the assessment string.
        Financial health scope (mandatory):
        - Discuss ONLY the current focus period (`focusMonthLabel`). Never mention prior months or cycles by name, past savings targets, or historical failures.
        - If `focusMonthLabel` is a date range, it is a billing cycle — say "this cycle" or use the label; do not call it "this month". If it is a single month name (for example "Aug 2026"), "this month" is fine.
        - All `healthBreakdown.reasons` refer to this focus period — keep the summary forward-looking and about where you stand now.
        Category facts: each category lists this period's total plus the biggest and smallest single spend in that category. Use those spends when they help; never invent ones that are not listed.
        Example tone (adapt into \(languageName)): "Your financial health is rated 4/5. Forecast savings rate is 19% — below the 20–30% guide. Shopping ran above your usual level."
        \(FinancialHealthRules.rulesPromptText())
        Facts JSON:
        \(json)
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: InsightsNarrativeResult.self)
            guard !Task.isCancelled else { return .empty }
            let content = response.content
            let rawSummary = content.healthSummary.trimmingCharacters(in: .whitespacesAndNewlines)
            let forecastRate = snapshot.forecast.expectedIncome > 0.01
                ? snapshot.forecast.expectedSavings / snapshot.forecast.expectedIncome
                : 0
            let aligned = FinancialHealthScoring.alignedHealthSummary(
                modelText: rawSummary,
                assessment: snapshot.healthBreakdown.savingsRateAssessment,
                ratePercent: snapshot.healthBreakdown.forecastSavingsRatePercent,
                forecastRate: forecastRate
            )
            let narratives = InsightsNarratives(
                healthSummary: aligned.text,
                personalityLabel: content.personalityLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                personalityBlurb: content.personalityBlurb.trimmingCharacters(in: .whitespacesAndNewlines),
                merchantGloss: content.merchantGloss.trimmingCharacters(in: .whitespacesAndNewlines),
                opportunities: content.opportunities
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty },
                wins: content.wins
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
            DeviceDebugLogger.log(
                "insights narrative generated",
                category: "insights.health",
                data: [
                    "assessment": snapshot.healthBreakdown.savingsRateAssessment,
                    "assessmentPct": snapshot.healthBreakdown.forecastSavingsRatePercent,
                    "rawHealthSummary": rawSummary,
                    "finalHealthSummary": narratives.healthSummary,
                    "corrected": aligned.corrected,
                    "stars": snapshot.healthBreakdown.finalStars,
                    "totalScore": snapshot.healthBreakdown.totalScore
                ]
            )
            return narratives
        } catch {
            DeviceDebugLogger.log(
                "insights narrative failed",
                category: "insights.health",
                data: ["error": String(describing: error), "slim": slim]
            )
            if !slim, Self.isContextWindowError(error) {
                return await generate(snapshot: snapshot, focusExpenses: focusExpenses, slim: true)
            }
            return .empty
        }
    }

    private static func isContextWindowError(_ error: Error) -> Bool {
        if let generation = error as? LanguageModelSession.GenerationError,
           case .exceededContextWindowSize = generation {
            return true
        }
        return String(describing: error).contains("exceededContextWindowSize")
    }

    private func loadDiskCache() -> [String: InsightsNarratives] {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: InsightsNarratives].self, from: data)
        else { return [:] }
        return decoded
    }

    private func persist(key: String, value: InsightsNarratives) {
        var map = loadDiskCache()
        map[key] = value
        if map.count > 12 {
            map = Dictionary(uniqueKeysWithValues: map.suffix(12))
        }
        guard let data = try? JSONEncoder().encode(map) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}

/// Curated facts for on-device Foundation Models — not the full Insights snapshot.
private struct NarrativeModelSnapshot: Encodable {
    struct Forecast: Encodable {
        let expectedIncome: Int
        let expectedExpense: Int
        let expectedSavings: Int
    }

    struct HealthBreakdown: Encodable {
        let finalStars: Int
        let totalScore: Double
        let forecastSavingsRatePercent: Int
        let savingsRateAssessment: String
        let reasons: [String]
    }

    struct Spend: Encodable {
        let title: String
        let amount: Int
    }

    struct CategoryFacts: Encodable {
        let name: String
        let total: Int
        let percentOfExpense: Int
        let vsUsual: String?
        let biggestSpend: Spend?
        let smallestSpend: Spend?

        enum CodingKeys: String, CodingKey {
            case name, total, percentOfExpense, vsUsual, biggestSpend, smallestSpend
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(total, forKey: .total)
            try container.encode(percentOfExpense, forKey: .percentOfExpense)
            try container.encodeIfPresent(vsUsual, forKey: .vsUsual)
            try container.encodeIfPresent(biggestSpend, forKey: .biggestSpend)
            try container.encodeIfPresent(smallestSpend, forKey: .smallestSpend)
        }
    }

    let focusMonthLabel: String
    let currencySymbol: String
    let forecast: Forecast
    let healthBreakdown: HealthBreakdown
    let categories: [CategoryFacts]
    let notableEvents: [Spend]
    let monthlySubscriptions: [Spend]

    enum CodingKeys: String, CodingKey {
        case focusMonthLabel, currencySymbol, forecast, healthBreakdown, categories, notableEvents, monthlySubscriptions
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(focusMonthLabel, forKey: .focusMonthLabel)
        try container.encode(currencySymbol, forKey: .currencySymbol)
        try container.encode(forecast, forKey: .forecast)
        try container.encode(healthBreakdown, forKey: .healthBreakdown)
        try container.encode(categories, forKey: .categories)
        if !notableEvents.isEmpty { try container.encode(notableEvents, forKey: .notableEvents) }
        if !monthlySubscriptions.isEmpty { try container.encode(monthlySubscriptions, forKey: .monthlySubscriptions) }
    }

    init(from snapshot: InsightsSnapshot, focusExpenses: [Transaction], slim: Bool) {
        let categoryLimit = slim ? 4 : 8
        let reasonLimit = slim ? 4 : 8
        focusMonthLabel = snapshot.focusMonthLabel
        currencySymbol = snapshot.currencySymbol
        forecast = Forecast(
            expectedIncome: snapshot.forecast.expectedIncome.roundedMoney,
            expectedExpense: snapshot.forecast.expectedExpense.roundedMoney,
            expectedSavings: snapshot.forecast.expectedSavings.roundedMoney
        )
        healthBreakdown = HealthBreakdown(
            finalStars: snapshot.healthBreakdown.finalStars,
            totalScore: (snapshot.healthBreakdown.totalScore * 10).rounded() / 10,
            forecastSavingsRatePercent: snapshot.healthBreakdown.forecastSavingsRatePercent,
            savingsRateAssessment: snapshot.healthBreakdown.savingsRateAssessment,
            reasons: Array(snapshot.healthBreakdown.reasons.prefix(reasonLimit))
        )

        let baselineById = Dictionary(
            uniqueKeysWithValues: snapshot.categoryBaselines.map { ($0.categoryId, $0.status.rawValue) }
        )
        let grouped = Dictionary(grouping: focusExpenses) {
            CategoryStore.shared.canonicalCategoryId(for: $0.categoryId)
        }
        let monthExpenseTotal = max(snapshot.categoryAllocation.reduce(0.0) { $0 + $1.amount }, 0.01)

        categories = grouped
            .map { id, txns -> CategoryFacts in
                let total = txns.reduce(0.0) { $0 + $1.totalAmount }
                let name = CategoryStore.shared.categoryDisplayName(for: id)
                let ranked = txns.sorted { $0.totalAmount > $1.totalAmount }
                let biggest = ranked.first
                let smallest = ranked.last
                let sameSpend = biggest?.id == smallest?.id
                return CategoryFacts(
                    name: name,
                    total: total.roundedMoney,
                    percentOfExpense: Int(((total / monthExpenseTotal) * 100).rounded()),
                    vsUsual: baselineById[id],
                    biggestSpend: biggest.map { Spend(title: $0.narrativeLabel, amount: $0.totalAmount.roundedMoney) },
                    smallestSpend: (sameSpend ? nil : smallest).map {
                        Spend(title: $0.narrativeLabel, amount: $0.totalAmount.roundedMoney)
                    }
                )
            }
            .sorted { $0.total > $1.total }
            .prefix(categoryLimit)
            .map { $0 }

        notableEvents = slim ? [] : snapshot.events.prefix(3).map {
            Spend(title: $0.title.clipped(to: 36), amount: $0.amount.roundedMoney)
        }
        monthlySubscriptions = slim ? [] : snapshot.subscriptions.prefix(4).map {
            Spend(title: $0.name.clipped(to: 28), amount: $0.monthly.roundedMoney)
        }
    }
}

private extension Double {
    var roundedMoney: Int { Int(rounded()) }
}

private extension String {
    func clipped(to maxLength: Int) -> String {
        guard count > maxLength else { return self }
        return String(prefix(maxLength))
    }
}

private extension Transaction {
    var narrativeLabel: String {
        let merchant = merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !merchant.isEmpty { return merchant.clipped(to: 32) }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { return trimmedTitle.clipped(to: 32) }
        return "Expense"
    }
}

extension InsightsNarratives: Codable {}
