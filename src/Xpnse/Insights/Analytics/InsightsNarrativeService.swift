//
//  InsightsNarrativeService.swift
//  Xpnse
//

import Foundation
import FoundationModels

@Generable
struct InsightsNarrativeResult {
    @Guide(description: "1-3 sentence overall financial health summary covering what happened, why it matters, and a gentle next step.")
    var healthSummary: String

    @Guide(description: "Short spending personality label e.g. planned spender, increasingly impulsive.")
    var personalityLabel: String

    @Guide(description: "1-2 sentence personality explanation grounded only in snapshot facts.")
    var personalityBlurb: String

    @Guide(description: "One line about top merchants. Empty if none.")
    var merchantGloss: String

    @Guide(description: "Up to 3 concrete opportunity lines with approximate savings when numbers exist in the snapshot.")
    var opportunities: [String]

    @Guide(description: "Up to 3 positive reinforcement lines celebrating real wins from the snapshot.")
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
        return base.appendingPathComponent("insights-narrative-cache.json")
    }

    func narratives(for snapshot: InsightsSnapshot) async -> InsightsNarratives {
        let key = snapshot.contentHash
        if let cached = memoryCache[key] {
            return cached
        }
        if let disk = loadDiskCache()[key] {
            memoryCache[key] = disk
            return disk
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
        You are a concise on-device financial coach for SnapLedger.
        Use ONLY the JSON snapshot below. Do not invent amounts, merchants, or categories.
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
