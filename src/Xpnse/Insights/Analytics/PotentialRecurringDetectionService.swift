//
//  PotentialRecurringDetectionService.swift
//  Xpnse
//

import CryptoKit
import Foundation
import FoundationModels

@Generable
struct PotentialRecurringHit {
    @Guide(description: "Transaction id exactly as listed in the prompt.")
    var transactionId: String

    @Guide(description: "Short reason tied to loan, EMI, subscription, rent, or utility bill only.")
    var reason: String

    @Guide(description: "Suggested cadence: daily, weekly, biweekly, monthly, bimonthly, or quarterly.")
    var suggestedFrequency: String

    @Guide(description: "Confidence 0-100 that this is a true recurring obligation (not a one-off). Only include items with confidence >= 80.")
    var confidencePercent: Int
}

@Generable
struct PotentialRecurringDetectionResult {
    @Guide(description: "Up to 8 items that are clearly loan/EMI/subscription/rent/utility (confidence >= 80). Empty if none.")
    var items: [PotentialRecurringHit]
}

/// Uses Foundation Models (with heuristic fallback) to suggest unmarked recurring spends.
@MainActor
final class PotentialRecurringDetectionService {
    static let shared = PotentialRecurringDetectionService()
    static let minimumConfidencePercent = 80

    private var memoryCache: [String: [InsightsPotentialRecurring]] = [:]
    private var task: Task<[InsightsPotentialRecurring], Never>?

    private var cacheURL: URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("insights-potential-recurring-v4.json")
    }

    func detect(
        transactions: [Transaction],
        recurringItems: [RecurringTransaction],
        focusYear: Int,
        focusMonth: Int,
        calendar: Calendar = .current
    ) async -> [InsightsPotentialRecurring] {
        await PotentialRecurringDismissStore.refreshCache()

        let candidates = Self.candidates(
            transactions: transactions,
            recurringItems: recurringItems,
            focusYear: focusYear,
            focusMonth: focusMonth,
            calendar: calendar
        )
        guard !candidates.isEmpty else { return [] }

        let key = Self.cacheKey(for: candidates)
        if InsightsResultCache.Policy.narrativeReadsEnabled {
            if let cached = memoryCache[key] { return cached }
            if let disk = loadDisk()[key] {
                memoryCache[key] = disk
                return disk
            }
        }

        task?.cancel()
        let work = Task<[InsightsPotentialRecurring], Never> {
            await self.resolve(candidates: candidates, cacheKey: key)
        }
        task = work
        return await work.value
    }

    private func resolve(
        candidates: [Transaction],
        cacheKey: String
    ) async -> [InsightsPotentialRecurring] {
        let result: [InsightsPotentialRecurring]
        if let fm = await classifyWithFoundationModel(candidates: candidates) {
            result = fm
        } else {
            result = Self.heuristic(candidates: candidates)
        }
        memoryCache[cacheKey] = result
        persist(key: cacheKey, value: result)
        let visible = result.filter { !PotentialRecurringDismissStore.isDismissed($0) }
        DeviceDebugLogger.log(
            "potential recurring detected",
            category: "insights.potentialRecurring",
            data: [
                "candidateCount": candidates.count,
                "resultCount": result.count,
                "visibleCount": visible.count,
                "minConfidence": Self.minimumConfidencePercent,
                "titles": visible.map(\.title),
                "confidences": visible.map(\.confidencePercent)
            ]
        )
        return visible
    }

    private func classifyWithFoundationModel(
        candidates: [Transaction]
    ) async -> [InsightsPotentialRecurring]? {
        guard FoundationModelsAvailability.isAvailable else { return nil }

        let catalog = candidates.map { tx in
            let date = Date(timeIntervalSince1970: tx.date)
            let day = date.formatted(date: .abbreviated, time: .omitted)
            let merchant = tx.merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "- id: \(tx.id) | type: \(tx.type.rawValue) | title: \(tx.title) | merchant: \(merchant) | amount: \(tx.totalAmount) | category: \(tx.categoryDisplayName) | date: \(day)"
        }
        .joined(separator: "\n")

        let prompt = """
        You help SnapLedger find THIS MONTH's transactions that should be tracked as recurring rules.
        Candidates are ALREADY keyword-filtered by type:
        - expense: loan, EMI, subscription, rent, or utility bill
        - income: salary/wages/pension/stipend/rental income/dividend/interest (or similar)
        - savings: SIP, RD, standing savings transfer, or clear recurring investment wording

        Strict rules:
        - Only include an item if confidencePercent is at least \(Self.minimumConfidencePercent).
        - Do NOT invent recurring labels for one-off income, gifts, rewards, ad-hoc savings, or
          discretionary expenses that lack those keywords.
        - If unsure, omit the transaction (do not guess).
        - Max 8 items. Use transaction ids exactly as given.
        - suggestedFrequency must be one of: daily, weekly, biweekly, monthly, bimonthly, quarterly.
        - confidencePercent is an integer 0-100.

        Transactions (focus month only):
        \(catalog)
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(
                to: prompt,
                generating: PotentialRecurringDetectionResult.self
            )
            let byId = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
            var seen = Set<String>()
            var mapped: [InsightsPotentialRecurring] = []
            var droppedLowConfidence = 0
            var droppedNoObligation = 0
            for hit in response.content.items {
                let id = hit.transactionId.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let tx = byId[id], !seen.contains(id) else { continue }
                seen.insert(id)
                if PotentialRecurringDismissStore.isDismissed(tx) { continue }
                let confidence = min(100, max(0, hit.confidencePercent))
                if confidence < Self.minimumConfidencePercent {
                    droppedLowConfidence += 1
                    continue
                }
                guard let kind = Self.obligationKind(for: tx) else {
                    droppedNoObligation += 1
                    continue
                }
                if Self.looksLikeOneOff(tx) { continue }
                mapped.append(
                    Self.map(
                        transaction: tx,
                        reason: hit.reason.isEmpty ? "Looks like \(kind.rawValue)" : hit.reason,
                        frequency: hit.suggestedFrequency,
                        confidencePercent: confidence
                    )
                )
                if mapped.count >= 8 { break }
            }
            return mapped
        } catch {
            DeviceDebugLogger.log(
                "potential recurring FM failed",
                category: "insights.potentialRecurring",
                data: ["error": String(describing: error)]
            )
            return nil
        }
    }

    /// Conservative fallback when FM is unavailable — obligation keywords only.
    private static func heuristic(candidates: [Transaction]) -> [InsightsPotentialRecurring] {
        var picks: [InsightsPotentialRecurring] = []
        var seen = Set<String>()

        for tx in candidates {
            guard let kind = obligationKind(for: tx) else { continue }
            guard !looksLikeOneOff(tx) else { continue }
            guard !PotentialRecurringDismissStore.isDismissed(tx) else { continue }
            guard seen.insert(tx.id).inserted else { continue }
            picks.append(
                map(
                    transaction: tx,
                    reason: "Matches \(kind.rawValue) keyword",
                    frequency: "monthly",
                    confidencePercent: 85
                )
            )
        }


        return Array(picks.prefix(8))
    }

    private static func map(
        transaction: Transaction,
        reason: String,
        frequency: String,
        confidencePercent: Int
    ) -> InsightsPotentialRecurring {
        InsightsPotentialRecurring(
            id: transaction.id,
            title: transaction.title,
            merchant: transaction.merchant,
            amount: transaction.totalAmount,
            categoryId: transaction.categoryId,
            date: transaction.date,
            type: transaction.type.rawValue,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            suggestedFrequency: normalizeFrequency(frequency),
            confidencePercent: confidencePercent
        )
    }

    static func normalizeFrequency(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "daily": return "daily"
        case "weekly": return "weekly"
        case "biweekly", "fortnightly", "every two weeks": return "biweekly"
        case "bimonthly", "every two months": return "bimonthly"
        case "quarterly": return "quarterly"
        default: return "monthly"
        }
    }

    static func recurrence(
        for suggestedFrequency: String,
        on date: Date,
        calendar: Calendar = .current
    ) -> RecurrenceFrequency {
        let options = RecurrenceFrequency.uiOptions(for: date, calendar: calendar)
        switch normalizeFrequency(suggestedFrequency) {
        case "daily":
            return .daily
        case "weekly":
            return options.first(where: {
                if case .weeklyOn = $0 { return true }
                return false
            }) ?? .daily
        case "biweekly":
            return options.first(where: {
                if case .everyTwoWeeksOn = $0 { return true }
                return false
            }) ?? .daily
        case "bimonthly":
            return options.first(where: {
                if case .onceInEveryTwoMonthsOn = $0 { return true }
                return false
            }) ?? .daily
        case "quarterly":
            return options.first(where: {
                if case .onceInEveryQuarterOn = $0 { return true }
                return false
            }) ?? .daily
        default:
            return options.first(where: {
                if case .monthlyOn = $0 { return true }
                return false
            }) ?? .daily
        }
    }

    /// Focus-month expense/income/savings with type-appropriate recurring keywords.
    private static func candidates(
        transactions: [Transaction],
        recurringItems: [RecurringTransaction],
        focusYear: Int,
        focusMonth: Int,
        calendar: Calendar
    ) -> [Transaction] {
        var skippedNoObligation = 0
        var skippedOneOff = 0
        var typeCounts: [String: Int] = [:]
        let filtered = transactions
            .filter { tx in
                guard tx.type == .expense || tx.type == .income || tx.type == .savings else {
                    return false
                }
                let comps = calendar.dateComponents([.year, .month], from: Date(timeIntervalSince1970: tx.date))
                guard comps.year == focusYear, comps.month == focusMonth else { return false }
                guard !tx.isRecurringGenerated else { return false }
                guard !recurringItems.contains(where: {
                    RecurringTransactionMatcher.matches(tx, rule: $0)
                }) else { return false }
                guard !PotentialRecurringDismissStore.isDismissed(tx) else { return false }
                guard tx.totalAmount > 0 else { return false }
                if looksLikeOneOff(tx) {
                    skippedOneOff += 1
                    return false
                }
                guard obligationKind(for: tx) != nil else {
                    skippedNoObligation += 1
                    return false
                }
                typeCounts[tx.type.rawValue, default: 0] += 1
                return true
            }
            .sorted { $0.totalAmount > $1.totalAmount }
            .prefix(30)
            .map { $0 }
        return filtered
    }

    private enum ObligationKind: String {
        case loan
        case emi
        case subscription
        case rent
        case utility
        case salary
        case recurringIncome
        case sip
        case recurringSavings
    }

    /// Title/notes/merchant must match type-appropriate recurring signals.
    private static func obligationKind(for tx: Transaction) -> ObligationKind? {
        let blob = descriptionBlob(for: tx)
        switch tx.type {
        case .expense:
            if containsAny(blob, loanKeywords) { return .loan }
            if containsAny(blob, emiKeywords) { return .emi }
            if containsAny(blob, subscriptionKeywords) { return .subscription }
            if containsAny(blob, rentKeywords) { return .rent }
            if containsAny(blob, utilityKeywords) { return .utility }
            if tx.categoryId == TransactionCategory.bills.rawValue { return .utility }
            return nil
        case .income:
            if containsAny(blob, salaryKeywords) { return .salary }
            if containsAny(blob, rentKeywords) { return .rent }
            if containsAny(blob, recurringIncomeKeywords) { return .recurringIncome }
            // Built-in Salary category is a strong recurring-income signal.
            if tx.categoryId == "salary" { return .salary }
            return nil
        case .savings:
            if containsAny(blob, sipKeywords) { return .sip }
            if containsAny(blob, recurringSavingsKeywords) { return .recurringSavings }
            if containsAny(blob, emiKeywords) { return .emi }
            // Investments category alone is not enough — require wording above.
            return nil
        }
    }

    private static func descriptionBlob(for tx: Transaction) -> String {
        [
            tx.title,
            tx.notes ?? "",
            tx.merchant ?? "",
            tx.categoryDisplayName
        ]
        .joined(separator: " ")
        .lowercased()
    }

    private static func containsAny(_ blob: String, _ keywords: [String]) -> Bool {
        keywords.contains { blob.contains($0) }
    }

    private static let loanKeywords: [String] = [
        "loan", "mortgage", "home loan", "personal loan", "car loan", "auto loan",
        "education loan", "student loan"
    ]

    private static let emiKeywords: [String] = [
        "emi", "e.m.i", "equated monthly", "installment", "instalment"
    ]

    private static let subscriptionKeywords: [String] = [
        "subscription", "subscribe", "membership", "monthly plan",
        "netflix", "spotify", "prime video", "amazon prime", "disney+", "disney plus",
        "hotstar", "youtube premium", "apple music", "apple tv", "icloud", "hulu",
        "hbo", "paramount+", "audible"
    ]

    private static let rentKeywords: [String] = [
        "rent", "rental", "lease", "house rent", "room rent", "hoa"
    ]

    private static let utilityKeywords: [String] = [
        "utility", "utilities", "electricity", "electric bill", "power bill",
        "water bill", "gas bill", "internet", "broadband", "wifi", "wi-fi",
        "cable bill", "phone bill", "mobile bill", "landline", "sewer", "trash bill"
    ]

    private static let salaryKeywords: [String] = [
        "salary", "paycheck", "pay cheque", "pay check", "wages", "wage",
        "stipend", "pension", "payroll", "take home", "take-home"
    ]

    private static let recurringIncomeKeywords: [String] = [
        "dividend", "interest", "rental income", "rent received", "allowance",
        "retainer", "annuity", "royalty", "commission"
    ]

    private static let sipKeywords: [String] = [
        "sip", "systematic investment", "systematic transfer", "stp"
    ]

    private static let recurringSavingsKeywords: [String] = [
        "recurring deposit", "rd installment", "auto transfer", "autosave",
        "auto save", "standing instruction", "monthly savings", "ppf", "epf",
        "nps", "provident fund"
    ]

    private static let oneOffCategoryIds: Set<String> = [
        "food", "transport", "shopping", "vacation", "gifts", "rewards"
    ]

    private static let oneOffKeywords: [String] = [
        "lunch", "dinner", "breakfast", "brunch", "coffee", "tea", "snack", "swiggy", "zomato",
        "fuel", "petrol", "diesel", "gas station", "parking", "uber", "ola", "taxi", "cab",
        "grocery", "groceries", "movie", "cinema", "ticket", "gift", "clothes", "amazon order",
        "bonus", "one time", "one-time", "one off", "one-off"
    ]

    private static func looksLikeOneOff(_ tx: Transaction) -> Bool {
        // Recurring-keyword matches always win over one-off heuristics.
        if obligationKind(for: tx) != nil {
            return false
        }
        if oneOffCategoryIds.contains(tx.categoryId) {
            return true
        }
        let blob = descriptionBlob(for: tx)
        return oneOffKeywords.contains(where: { blob.contains($0) })
    }

    private static func cacheKey(for candidates: [Transaction]) -> String {
        let lines = candidates
            .map { "\($0.id):\($0.type.rawValue):\($0.date):\($0.totalAmount):\($0.title)" }
            .sorted()
            .joined(separator: "|")
        let digest = SHA256.hash(data: Data(("v4|" + lines).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadDisk() -> [String: [InsightsPotentialRecurring]] {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: [InsightsPotentialRecurring]].self, from: data)
        else { return [:] }
        return decoded
    }

    private func persist(key: String, value: [InsightsPotentialRecurring]) {
        var map = loadDisk()
        map[key] = value
        if map.count > 16 {
            map = Dictionary(uniqueKeysWithValues: map.suffix(16))
        }
        guard let data = try? JSONEncoder().encode(map) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
