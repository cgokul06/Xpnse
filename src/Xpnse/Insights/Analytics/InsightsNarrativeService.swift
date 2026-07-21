//
//  InsightsNarrativeService.swift
//  Xpnse
//

import Foundation
import FoundationModels

@Generable
struct InsightsNarrativeResult {
    @Guide(description: "1-3 sentences in second person (you/your) about the current focus month only. Cover where you stand now, why it matters, and a gentle next step. Never mention prior months or say 'the user'.")
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
        return base.appendingPathComponent("insights-narrative-cache-v3.json")
    }

    func narratives(for snapshot: InsightsSnapshot) async -> InsightsNarratives {
        let key = snapshot.contentHash
        if InsightsResultCache.Policy.narrativeReadsEnabled {
            if let cached = memoryCache[key] {
                return cached
            }
            if let disk = loadDiskCache()[key] {
                memoryCache[key] = disk
                return disk
            }
        }

        guard FoundationModelsAvailability.isAvailable else {
            return .empty
        }

        task?.cancel()
        let work = Task<InsightsNarratives, Never> { @MainActor in
            await self.generate(snapshot: snapshot)
        }
        task = work
        let result = await work.value
        if result.hasContent {
            memoryCache[key] = result
            persist(key: key, value: result)
        }
        return result
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func generate(snapshot: InsightsSnapshot) async -> InsightsNarratives {
        guard !Task.isCancelled else { return .empty }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(snapshot),
              let json = String(data: data, encoding: .utf8)
        else { return .empty }

        let prompt = """
        You are a concise on-device financial coach for SnapLedger, speaking directly to the person reading.
        Voice rules (mandatory):
        - Always use second person: "you", "your", "you're", "you've".
        - Never write "the user", "user", "they", "their", or third-person observations about the reader.
        - Prefer openings like "You are…", "You seem like…", "Your spending…", "You've…".
        Use ONLY the JSON snapshot below. Do not invent amounts, merchants, or categories.
        The financial health star rating is already computed in `healthBreakdown.finalStars` and `healthBreakdown.totalScore`.
        Do NOT change or recalculate the score. Explain it using `healthBreakdown.reasons`.
        Financial health scope (mandatory):
        - Discuss ONLY the current focus month (`focusMonthLabel`). Never mention prior months by name, past savings targets, or historical failures.
        - All `healthBreakdown.reasons` refer to this month — keep the summary forward-looking and about where you stand now.
        Example tone: "Your financial health is rated 4/5. You're on track with forecast savings this month, though shopping ran above your usual level."
        \(FinancialHealthRules.rulesPromptText())
        Snapshot JSON:
        \(json)
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: InsightsNarrativeResult.self)
            guard !Task.isCancelled else { return .empty }
            let content = response.content
            return InsightsNarratives(
                healthSummary: content.healthSummary.trimmingCharacters(in: .whitespacesAndNewlines),
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
        } catch {
            return .empty
        }
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

extension InsightsNarratives: Codable {}
