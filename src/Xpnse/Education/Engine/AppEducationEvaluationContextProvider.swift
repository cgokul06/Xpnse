//
//  AppEducationEvaluationContextProvider.swift
//  Xpnse
//

import Foundation

/// Live evaluation snapshot built from local transactions, recurring rules, and categories.
final class AppEducationEvaluationContextProvider: EducationEvaluationContextProviding, @unchecked Sendable {
    static let shared = AppEducationEvaluationContextProvider()

    private let lock = NSLock()
    private var cachedContext = CampaignContext()
    private let transactionRepository: TransactionRepository
    private let recurringRepository: RecurringRepository
    private let loadCategories: @MainActor () -> [CategoryDefinition]

    init(
        transactionRepository: TransactionRepository = SwiftDataTransactionRepository.shared,
        recurringRepository: RecurringRepository = SwiftDataRecurringRepository.shared,
        loadCategories: @escaping @MainActor () -> [CategoryDefinition] = {
            CategoryStore.shared.categories
        }
    ) {
        self.transactionRepository = transactionRepository
        self.recurringRepository = recurringRepository
        self.loadCategories = loadCategories
    }

    func refresh() async {
        let transactions = (try? await transactionRepository.fetchAll()) ?? []
        let recurring = (try? await recurringRepository.fetchAll()) ?? []
        let categories = await MainActor.run { loadCategories() }
        let context = Self.makeCampaignContext(
            transactions: transactions,
            recurring: recurring,
            categories: categories
        )
        lock.lock()
        cachedContext = context
        lock.unlock()
    }

    func snapshot(for event: EducationEvent, at date: Date) -> EducationEvaluationSnapshot {
        lock.lock()
        let cached = cachedContext
        lock.unlock()
        return EducationEvaluationSnapshot(campaignContext: cached, at: date)
    }

    static func makeCampaignContext(
        transactions: [Transaction],
        recurring: [RecurringTransaction],
        categories: [CategoryDefinition],
        evaluationDate: Date = Date()
    ) -> CampaignContext {
        let incomeTransactions = transactions.filter { $0.type == .income }
        let hasRecurringIncome = recurring.contains {
            $0.state == .active && $0.type == TransactionType.income.rawValue
        }
        let customCategoryCount = categories.filter { !$0.isBuiltIn && !$0.isDeleted }.count
        return CampaignContext(
            transactionCount: transactions.count,
            incomeCount: incomeTransactions.count,
            hasRecurringIncome: hasRecurringIncome,
            hasConfiguredIncome: !incomeTransactions.isEmpty || hasRecurringIncome,
            customCategoryCount: customCategoryCount,
            evaluationDate: evaluationDate
        )
    }
}
