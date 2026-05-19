import Foundation

/// A single suggestion entry.
public struct SuggestionItem: Codable, Hashable {
    public let title: String
    public let categoryIdentifier: String?
    public var frequency: Int
    public var lastUsed: Date
    /// Lowercased & trimmed title for search
    public var normalized: String { SuggestionEngine.normalize(title) }
}

/// Protocol representing the minimal required properties from a transaction-like object.
public protocol TransactionLike {
    var title: String { get }
    var categoryIdentifier: String? { get }
    var date: Date { get }
}

struct TransactionAdapter: TransactionLike {
    let title: String
    let categoryIdentifier: String?
    let date: Date
}


@MainActor
public final class SuggestionEngine {
    /// Configurable lookback (in months) for suggestion rebuild after import.
    public static var importRebuildLookbackMonths: Int = 3

    private var suggestions: [SuggestionItem] = []
    private var buckets: [String: [SuggestionItem]] = [:]
    
    private var debounceTask: Task<Void, Never>? = nil
    
    private let persistenceURL: URL = {
        let fm = FileManager.default
        let base = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = (base ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first!)
        return dir.appendingPathComponent("suggestions.json")
    }()
    
    public init() {}
    
    // MARK: - Public API
    
    /// Builds the suggestion engine indices from a collection of transaction-like objects.
    /// - Parameter transactions: Array of objects conforming to `TransactionLike`.
    public func build(from transactions: [TransactionLike]) {
        suggestions.removeAll()
        buckets.removeAll()
        
        var frequencyMap: [String: SuggestionItem] = [:]
        
        for tx in transactions {
            let normalized = Self.normalize(tx.title)
            guard !normalized.isEmpty else { continue }
            
            let key = frequencyMapKey(title: tx.title)
            
            if let existing = frequencyMap[key] {
                let freq = existing.frequency + 1
                let lastUsed = max(existing.lastUsed, tx.date)
                let resolvedCategory = lastUsed == tx.date ? tx.categoryIdentifier : existing.categoryIdentifier
                frequencyMap[key] = SuggestionItem(
                    title: tx.title,
                    categoryIdentifier: resolvedCategory,
                    frequency: freq,
                    lastUsed: lastUsed
                )
            } else {
                frequencyMap[key] = SuggestionItem(title: tx.title, categoryIdentifier: tx.categoryIdentifier, frequency: 1, lastUsed: tx.date)
            }
        }
        
        suggestions = Array(frequencyMap.values)
        buildBuckets()
        save()
    }
    
    /// Inserts or updates a single transaction-like item into the suggestion engine.
    /// - Parameter transaction: The transaction-like object to upsert.
    public func upsert(from transaction: TransactionLike) {
        let normalized = Self.normalize(transaction.title)
        guard !normalized.isEmpty else { return }
        
        let key = frequencyMapKey(title: transaction.title)
        
        if let index = suggestions.firstIndex(where: { frequencyMapKey(title: $0.title) == key }) {
            let old = suggestions[index]
            let newFreq = old.frequency + 1
            let newLastUsed = max(old.lastUsed, transaction.date)
            let updated = SuggestionItem(
                title: transaction.title,
                categoryIdentifier: newLastUsed == transaction.date ? transaction.categoryIdentifier : old.categoryIdentifier,
                frequency: newFreq,
                lastUsed: newLastUsed
            )
            suggestions[index] = updated
        } else {
            let newItem = SuggestionItem(title: transaction.title, categoryIdentifier: transaction.categoryIdentifier, frequency: 1, lastUsed: transaction.date)
            suggestions.append(newItem)
        }
        buildBuckets()
        save()
    }

    /// Decrements usage count for a transaction title.
    /// Removes the suggestion when frequency reaches zero.
    /// - Parameter title: The transaction title to decrement.
    public func decrement(title: String) {
        let key = frequencyMapKey(title: title)
        guard !key.isEmpty else { return }

        guard let index = suggestions.firstIndex(where: { frequencyMapKey(title: $0.title) == key }) else {
            return
        }

        if suggestions[index].frequency <= 1 {
            suggestions.remove(at: index)
        } else {
            suggestions[index].frequency -= 1
            suggestions[index].lastUsed = Date()
        }

        buildBuckets()
        save()
    }
    
    /// Queries the suggestion engine immediately for matching suggestions.
    /// - Parameters:
    ///   - text: The text to query.
    ///   - limit: Maximum number of results to return. Default is 8.
    /// - Returns: Array of matching `SuggestionItem`s.
    public func query(_ text: String, limit: Int = 8) -> [SuggestionItem] {
        let normalized = Self.normalize(text)
        guard !normalized.isEmpty else { return [] }
        
        let bucketKey = Self.bucketKey(for: normalized)
        
        let candidates = buckets[bucketKey, default: []]
        
        let filtered = candidates.filter { $0.normalized.contains(normalized) }
        
        let sorted = filtered.sorted { lhs, rhs in
            // Priority 1: prefix matches first
            let lhsPrefix = lhs.normalized.hasPrefix(normalized)
            let rhsPrefix = rhs.normalized.hasPrefix(normalized)
            if lhsPrefix != rhsPrefix { return lhsPrefix && !rhsPrefix }
            // Priority 2: higher frequency
            if lhs.frequency != rhs.frequency { return lhs.frequency > rhs.frequency }
            // Priority 3: more recent lastUsed
            return lhs.lastUsed > rhs.lastUsed
        }
        return Array(sorted.prefix(limit))
    }
    
    /// Queries the suggestion engine with a debounce delay (~150ms) before invoking the handler.
    /// Only the latest query is processed.
    /// - Parameters:
    ///   - text: The text to query.
    ///   - limit: Maximum number of results to return. Default is 8.
    ///   - handler: Closure to be called on the main thread with the results.
    public func queryDebounced(_ text: String, limit: Int = 8, handler: @escaping ([SuggestionItem]) -> Void) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150 ms
            
            guard let self = self, !Task.isCancelled else { return }
            
            let results = await self.query(text, limit: limit)
            
            DispatchQueue.main.async {
                handler(results)
            }
        }
    }
    
    /// Resets the suggestion engine, clearing all stored suggestions.
    public func reset() {
        suggestions.removeAll()
        buckets.removeAll()
        debounceTask?.cancel()
        debounceTask = nil
        save()
    }
    
    /// Saves current suggestions to disk as JSON.
    public func save() {
        do {
            let data = try JSONEncoder().encode(suggestions)
            try data.write(to: persistenceURL, options: [.atomic])
        } catch {
            // You may want to log this in your logging system
        }
    }
    
    /// Loads suggestions from disk (if available) and rebuilds buckets.
    public func load() {
        do {
            let data = try Data(contentsOf: persistenceURL)
            let decoded = try JSONDecoder().decode([SuggestionItem].self, from: data)
            suggestions = Self.mergeByNormalizedTitle(decoded)
            buildBuckets()
        } catch {
            // If file missing or decode fails, start empty
            suggestions = []
            buckets = [:]
        }
    }

    /// Rebuilds suggestions from recent transactions only, using a month-based lookback.
    /// Existing suggestions are replaced by the rebuilt dataset.
    /// - Parameters:
    ///   - transactions: Source transactions.
    ///   - monthsBack: Number of months to look back from now.
    func rebuildFromRecentTransactions(_ transactions: [Transaction], monthsBack: Int) {
        let sanitizedMonths = max(1, monthsBack)
        let now = Date()
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .month, value: -sanitizedMonths, to: now) ?? now

        let adapters: [TransactionAdapter] = transactions
            .map {
                TransactionAdapter(
                    title: $0.title,
                    categoryIdentifier: $0.categoryId,
                    date: Date(timeIntervalSince1970: $0.date)
                )
            }
            .filter { $0.date >= cutoff }

        build(from: adapters)
    }
    
    // MARK: - Private Helpers
    
    private func buildBuckets() {
        buckets.removeAll()
        for item in suggestions {
            let key = Self.bucketKey(for: item.normalized)
            buckets[key, default: []].append(item)
        }
    }
    
    static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private static func bucketKey(for normalized: String) -> String {
        let prefix = normalized.prefix(2)
        if prefix.count == 2 {
            return String(prefix)
        } else if prefix.count == 1 {
            return String(prefix) + " "
        } else {
            return "  "
        }
    }
    
    private static func mergeByNormalizedTitle(_ items: [SuggestionItem]) -> [SuggestionItem] {
        var merged: [String: SuggestionItem] = [:]
        for item in items {
            let key = normalize(item.title)
            guard !key.isEmpty else { continue }
            if let existing = merged[key] {
                let combinedFrequency = existing.frequency + item.frequency
                let latest = existing.lastUsed >= item.lastUsed ? existing : item
                merged[key] = SuggestionItem(
                    title: latest.title,
                    categoryIdentifier: latest.categoryIdentifier,
                    frequency: combinedFrequency,
                    lastUsed: latest.lastUsed
                )
            } else {
                merged[key] = item
            }
        }
        return Array(merged.values)
    }

    private func frequencyMapKey(title: String) -> String {
        Self.normalize(title)
    }
}
