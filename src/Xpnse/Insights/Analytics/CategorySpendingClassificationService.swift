//
//  CategorySpendingClassificationService.swift
//  Xpnse
//

import CryptoKit
import Foundation
import FoundationModels

enum CategorySpendingRole: String, Codable, Sendable {
    case discretionary
    case fixed
}

struct CategorySpendingRoles: Codable, Equatable, Sendable {
    let revision: String
    let discretionaryIds: Set<String>
    let fixedIds: Set<String>
}

@Generable
struct CategorySpendingRoleAssignment {
    @Guide(description: "Expense category id exactly as listed in the prompt.")
    var categoryId: String

    @Guide(description: "Either discretionary or fixed.")
    var role: String
}

@Generable
struct CategorySpendingClassificationResult {
    @Guide(description: "One entry per expense category id from the prompt.")
    var assignments: [CategorySpendingRoleAssignment]
}

/// Classifies expense categories as discretionary vs fixed for health scoring.
/// Results are cached by category catalog revision so scoring stays deterministic.
@MainActor
final class CategorySpendingClassificationService {
    static let shared = CategorySpendingClassificationService()

    private var memoryCache: CategorySpendingRoles?
    private var task: Task<CategorySpendingRoles, Never>?

    private var cacheURL: URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("insights-category-spending-roles.json")
    }

    func roles(for categories: [CategoryDefinition]) async -> CategorySpendingRoles {
        let expenseCategories = categories.filter { $0.transactionType == .expense && !$0.isDeleted }
        let revision = Self.revision(for: expenseCategories)

        if let memoryCache, memoryCache.revision == revision {
            return memoryCache
        }
        if let disk = loadDisk(), disk.revision == revision {
            memoryCache = disk
            return disk
        }

        task?.cancel()
        let work = Task<CategorySpendingRoles, Never> {
            await self.resolveRoles(expenseCategories: expenseCategories, revision: revision)
        }
        task = work
        let result = await work.value
        memoryCache = result
        persist(result)
        return result
    }

    private func resolveRoles(
        expenseCategories: [CategoryDefinition],
        revision: String
    ) async -> CategorySpendingRoles {
        if let fmRoles = await classifyWithFoundationModel(expenseCategories: expenseCategories, revision: revision) {
            return fmRoles
        }
        return Self.heuristicRoles(expenseCategories: expenseCategories, revision: revision)
    }

    private func classifyWithFoundationModel(
        expenseCategories: [CategoryDefinition],
        revision: String
    ) async -> CategorySpendingRoles? {
        guard FoundationModelsAvailability.isAvailable, !expenseCategories.isEmpty else {
            return nil
        }

        let catalog = expenseCategories
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { "- id: \($0.id), name: \($0.name)" }
            .joined(separator: "\n")

        let prompt = """
        Classify each expense category as discretionary or fixed for financial health scoring.

        Discretionary examples: shopping, dining, entertainment, travel, personal care, hobbies.
        Fixed examples: rent, insurance, utilities, medical, education, taxes, EMIs, house construction.

        Return exactly one assignment per category id below. Use only "discretionary" or "fixed".

        Categories:
        \(catalog)
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(
                to: prompt,
                generating: CategorySpendingClassificationResult.self
            )
            let validIds = Set(expenseCategories.map(\.id))
            var discretionary: Set<String> = []
            var fixed: Set<String> = []

            for item in response.content.assignments {
                guard validIds.contains(item.categoryId) else { continue }
                let role = item.role.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if role.contains("discretionary") {
                    discretionary.insert(item.categoryId)
                } else if role.contains("fixed") {
                    fixed.insert(item.categoryId)
                }
            }

            // Ensure every category has a role; fill gaps with heuristics.
            let fallback = Self.heuristicRoles(expenseCategories: expenseCategories, revision: revision)
            for id in validIds {
                if discretionary.contains(id) || fixed.contains(id) { continue }
                if fallback.discretionaryIds.contains(id) {
                    discretionary.insert(id)
                } else {
                    fixed.insert(id)
                }
            }

            return CategorySpendingRoles(
                revision: revision,
                discretionaryIds: discretionary,
                fixedIds: fixed
            )
        } catch {
            return nil
        }
    }

    static func heuristicRoles(
        expenseCategories: [CategoryDefinition],
        revision: String
    ) -> CategorySpendingRoles {
        var discretionary: Set<String> = []
        var fixed: Set<String> = []

        let discretionaryBuiltIn: Set<String> = ["shopping", "food", "transport"]
        let fixedBuiltIn: Set<String> = ["bills", "health"]

        for category in expenseCategories {
            let id = category.id.lowercased()
            let name = category.name.lowercased()

            if fixedBuiltIn.contains(id) || matchesFixedKeywords(name) {
                fixed.insert(category.id)
            } else if discretionaryBuiltIn.contains(id) || matchesDiscretionaryKeywords(name) {
                discretionary.insert(category.id)
            } else {
                fixed.insert(category.id)
            }
        }

        return CategorySpendingRoles(
            revision: revision,
            discretionaryIds: discretionary,
            fixedIds: fixed
        )
    }

    private static func matchesDiscretionaryKeywords(_ name: String) -> Bool {
        let keys = [
            "shop", "dining", "dine", "restaurant", "entertain", "travel", "trip",
            "hobby", "hobbies", "personal care", "salon", "spa", "movie", "game", "leisure"
        ]
        return keys.contains { name.contains($0) }
    }

    private static func matchesFixedKeywords(_ name: String) -> Bool {
        let keys = [
            "rent", "insurance", "utilit", "medical", "health", "education", "school",
            "tax", "emi", "loan", "mortgage", "construction", "bill", "utility"
        ]
        return keys.contains { name.contains($0) }
    }

    static func revision(for categories: [CategoryDefinition]) -> String {
        let lines = categories
            .filter { $0.transactionType == .expense && !$0.isDeleted }
            .sorted { $0.id < $1.id }
            .map { "\($0.id)|\($0.name)|\($0.updatedAt.timeIntervalSince1970)" }
        let joined = lines.joined(separator: ";")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadDisk() -> CategorySpendingRoles? {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode(CategorySpendingRoles.self, from: data)
        else { return nil }
        return decoded
    }

    private func persist(_ roles: CategorySpendingRoles) {
        guard let data = try? JSONEncoder().encode(roles) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
