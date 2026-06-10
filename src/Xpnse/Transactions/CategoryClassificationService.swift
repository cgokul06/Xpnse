//
//  CategoryClassificationService.swift
//  Xpnse
//

import Foundation
import FoundationModels

@Generable
struct CategoryClassification {
    @Guide(description: "Category id from the allowed list in the prompt.")
    var categoryId: String
}

@MainActor
final class CategoryClassificationService {
    private var classificationTask: Task<String?, Never>?

    func classify(description: String, transactionType: TransactionType) async -> String? {
        classificationTask?.cancel()

        let task = Task<String?, Never> { @MainActor in
            let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 3 else { return nil }
            guard !Task.isCancelled else { return nil }

            guard case .available = SystemLanguageModel.default.availability else {
                return nil
            }

            await CategoryStore.shared.load()
            let guide = CategoryStore.shared.categoryGuideDescription(for: transactionType)
            let prompt = """
            Classify this \(transactionType.rawValue) transaction description into the best matching category.
            \(guide)
            Description: \(trimmed)
            """

            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt, generating: CategoryClassification.self)
                guard !Task.isCancelled else { return nil }
                return CategoryStore.shared.mapScannedCategoryId(
                    response.content.categoryId,
                    transactionType: transactionType
                )
            } catch {
                return nil
            }
        }

        classificationTask = task
        return await task.value
    }

    func cancel() {
        classificationTask?.cancel()
        classificationTask = nil
    }
}
