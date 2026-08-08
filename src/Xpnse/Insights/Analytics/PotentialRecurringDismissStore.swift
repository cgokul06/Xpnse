//
//  PotentialRecurringDismissStore.swift
//  Xpnse
//

import Foundation

/// Domain record for a user-marked "not recurring" Insights suggestion.
struct PotentialRecurringDismissRecord: Codable, Equatable, Hashable, Sendable, Identifiable {
    let id: String
    let transactionId: String
    /// Stable key: normalized title|merchant|categoryId
    let fingerprint: String
    let dismissedAt: Date
    let updatedAt: Date

    init(
        id: String = UUID().uuidString,
        transactionId: String,
        fingerprint: String,
        dismissedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.transactionId = transactionId
        self.fingerprint = fingerprint
        self.dismissedAt = dismissedAt
        self.updatedAt = updatedAt
    }
}

/// Facade over SwiftData dismissals (with one-time JSON migration + in-memory lookup cache).
@MainActor
enum PotentialRecurringDismissStore {
    private static let legacyFileName = "insights-potential-recurring-dismissed-v1.json"
    private static let repository: PotentialRecurringDismissRepository =
        SwiftDataPotentialRecurringDismissRepository.shared

    private static var cachedIds: Set<String> = []
    private static var cachedFingerprints: Set<String> = []
    private static var didLoadCache = false
    private static var didMigrateLegacy = false

    static func fingerprint(
        title: String,
        merchant: String?,
        categoryId: String
    ) -> String {
        let t = RecurringTransactionMatcher.normalized(title)
        let m = RecurringTransactionMatcher.normalized(merchant ?? "")
        let c = categoryId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(t)|\(m)|\(c)"
    }

    static func fingerprint(for item: InsightsPotentialRecurring) -> String {
        fingerprint(title: item.title, merchant: item.merchant, categoryId: item.categoryId)
    }

    static func fingerprint(for transaction: Transaction) -> String {
        fingerprint(title: transaction.title, merchant: transaction.merchant, categoryId: transaction.categoryId)
    }

    static func isDismissed(transactionId: String, fingerprint: String) -> Bool {
        ensureCacheLoadedSyncIfPossible()
        return cachedIds.contains(transactionId) || cachedFingerprints.contains(fingerprint)
    }

    static func isDismissed(_ item: InsightsPotentialRecurring) -> Bool {
        isDismissed(transactionId: item.id, fingerprint: fingerprint(for: item))
    }

    static func isDismissed(_ transaction: Transaction) -> Bool {
        isDismissed(transactionId: transaction.id, fingerprint: fingerprint(for: transaction))
    }

    static func dismiss(_ item: InsightsPotentialRecurring) async {
        await migrateLegacyJSONIfNeeded()
        let fp = fingerprint(for: item)
        let record = PotentialRecurringDismissRecord(
            transactionId: item.id,
            fingerprint: fp
        )
        do {
            try await repository.upsert(record)
            cachedIds.insert(item.id)
            cachedFingerprints.insert(fp)
            didLoadCache = true
        } catch {
            DeviceDebugLogger.log(
                "potential recurring dismiss save failed",
                category: "insights.potentialRecurring",
                data: ["error": error.localizedDescription]
            )
        }
        DeviceDebugLogger.log(
            "potential recurring dismissed",
            category: "insights.potentialRecurring",
            data: [
                "transactionId": item.id,
                "title": item.title,
                "fingerprint": fp
            ]
        )
    }

    static func refreshCache() async {
        await migrateLegacyJSONIfNeeded()
        do {
            let all = try await repository.fetchAll()
            applyCache(all)
        } catch {
            DeviceDebugLogger.log(
                "potential recurring dismiss cache load failed",
                category: "insights.potentialRecurring",
                data: ["error": error.localizedDescription]
            )
        }
    }

    static func fetchAllForExport() async throws -> [PotentialRecurringDismissRecord] {
        await migrateLegacyJSONIfNeeded()
        return try await repository.fetchAll()
    }

    static func importRecords(_ records: [PotentialRecurringDismissRecord]) async throws {
        for record in records {
            try await repository.upsert(record)
        }
        await refreshCache()
    }

    static func clearAll() async throws {
        try await repository.clearAll()
        cachedIds = []
        cachedFingerprints = []
        didLoadCache = true
    }

    private static func applyCache(_ records: [PotentialRecurringDismissRecord]) {
        cachedIds = Set(records.map(\.transactionId))
        cachedFingerprints = Set(records.map(\.fingerprint))
        didLoadCache = true
    }

    /// Best-effort sync warm for filters already on the main actor after async refresh.
    private static func ensureCacheLoadedSyncIfPossible() {
        guard !didLoadCache else { return }
        // Cache is filled asynchronously via `refreshCache()` before detection runs.
    }

    private static func migrateLegacyJSONIfNeeded() async {
        guard !didMigrateLegacy else { return }
        didMigrateLegacy = true

        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )) ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent(legacyFileName)
        guard fm.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else { return }

        // Legacy JSON had no `id` / `updatedAt` — decode a soft shape.
        struct LegacyRecord: Codable {
            let transactionId: String
            let fingerprint: String
            let dismissedAt: Date
        }
        guard let legacy = try? JSONDecoder().decode([LegacyRecord].self, from: data) else {
            try? fm.removeItem(at: url)
            return
        }

        for item in legacy {
            let record = PotentialRecurringDismissRecord(
                transactionId: item.transactionId,
                fingerprint: item.fingerprint,
                dismissedAt: item.dismissedAt,
                updatedAt: item.dismissedAt
            )
            try? await repository.upsert(record)
        }
        try? fm.removeItem(at: url)
        DeviceDebugLogger.log(
            "migrated legacy potential-recurring dismiss JSON",
            category: "insights.potentialRecurring",
            data: ["count": legacy.count]
        )
    }
}
