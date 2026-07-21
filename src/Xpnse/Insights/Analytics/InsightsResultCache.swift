//
//  InsightsResultCache.swift
//  Xpnse
//

import CryptoKit
import Foundation

/// Persists the last Insights analytics payload and regenerates only when the
/// underlying transaction/recurring revision (or calendar day / currency) changes.
struct InsightsCachedResult: Codable, Equatable, Sendable {
    let revision: String
    let generatedAt: Date
    let year: Int
    let expenseTrend: ExpenseTrendChartModel
    let snapshot: InsightsSnapshot
    let narratives: InsightsNarratives
}

enum InsightsResultCache {
    private static let fileName = "insights-result-cache.json"
    private static var memory: InsightsCachedResult?

    private static var cacheURL: URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(fileName)
    }

    /// Fingerprint of data that Insights depends on.
    static func revision(
        transactionUpdatedAtById: [String: Date],
        recurringUpdatedAtById: [UUID: Date],
        focusDay: Date,
        currencyCode: String,
        calendar: Calendar = .current
    ) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: focusDay)
        let dayKey = "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"

        var lines: [String] = [
            "schema:category-health-v2",
            "day:\(dayKey)",
            "currency:\(currencyCode)"
        ]
        for (id, updatedAt) in transactionUpdatedAtById.sorted(by: { $0.key < $1.key }) {
            lines.append("t:\(id):\(updatedAt.timeIntervalSince1970)")
        }
        for (id, updatedAt) in recurringUpdatedAtById.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            lines.append("r:\(id.uuidString):\(updatedAt.timeIntervalSince1970)")
        }

        let joined = lines.joined(separator: "|")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func load(matching revision: String) -> InsightsCachedResult? {
        if let memory, memory.revision == revision {
            return memory
        }
        guard let disk = loadDisk(), disk.revision == revision else { return nil }
        memory = disk
        return disk
    }

    /// Any cached payload (used to paint instantly while verifying revision).
    static func loadAny() -> InsightsCachedResult? {
        if let memory { return memory }
        let disk = loadDisk()
        memory = disk
        return disk
    }

    static func save(_ result: InsightsCachedResult) {
        memory = result
        guard let data = try? JSONEncoder().encode(result) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    static func clear() {
        memory = nil
        try? FileManager.default.removeItem(at: cacheURL)
    }

    private static func loadDisk() -> InsightsCachedResult? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(InsightsCachedResult.self, from: data)
    }
}
