//
//  FirebaseTransactionManager.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class FirebaseTransactionManager: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var reloadTransactions: Bool = false
    @Published private(set) var transactionSummary: TransactionSummary?

    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private let authManager: FirebaseAuthManager
    private var cancellables: Set<AnyCancellable> = []

    init(authManager: FirebaseAuthManager) {
        self.authManager = authManager
//        setupAuthListener()
    }

    // MARK: - Authentication Listener

//    private func setupAuthListener() {
//        authManager.$isAuthenticated
//            .sink { [weak self] isAuthenticated in
//                if isAuthenticated ?? false {
//                    Task {
//                        await self?.loadTransactionsForCurrentlyShownTimePeriod()
//                    }
//                } else {
//                    self?.transactions = []
//                    self?.removeListener()
//                }
//            }
//            .store(in: &cancellables)
//    }

    /// Loads the transactions for current selected/showing time period
//    private func loadTransactionsForCurrentlyShownTimePeriod() async {
//        // TODO: GC, set start and end date as user default setting
//        guard let startDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())),
//              let endDate = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) else {
//            return
//        }
//
//        await self.loadTransactions(startDate: startDate, endDate: endDate)
//    }

    func resetReloadTransaction() {
        self.reloadTransactions = false
    }

    // MARK: - CRUD Operations

    func addTransaction(_ transaction: Transaction) async {
        guard let userId = authManager.userId else {
            errorMessage = "User not authenticated"
            return
        }

        isLoading = true

        do {
            let transactionData = transaction.toFirestoreData()
            var dataWithTimestamps = transactionData
            dataWithTimestamps["createdAt"] = FieldValue.serverTimestamp()
            dataWithTimestamps["updatedAt"] = FieldValue.serverTimestamp()

            // New structure: users/{userId}/transactions/{transactionId}
            try await db.collection("users")
                .document(userId)
                .collection("transactions_data")
                .document(transaction.id)
                .setData(dataWithTimestamps)

//            await loadTransactionsForCurrentlyShownTimePeriod()
            self.reloadTransactions = true
        } catch {
            errorMessage = "Failed to add transaction: \(error.localizedDescription)"
        }

        isLoading = false
    }

//    func updateTransaction(_ transaction: Transaction) async {
//        guard let userId = authManager.userId else {
//            errorMessage = "User not authenticated"
//            return
//        }
//
//        isLoading = true
//
//        do {
//            var transactionData = transaction.toFirestoreData()
//            transactionData["updatedAt"] = FieldValue.serverTimestamp()
//
//            try await db.collection("users")
//                .document(userId)
//                .collection("transactions_data")
//                .document(transaction.id)
//                .setData(transactionData, merge: true)
//
//            await loadTransactionsForCurrentlyShownTimePeriod()
//        } catch {
//            errorMessage = "Failed to update transaction: \(error.localizedDescription)"
//        }
//
//        isLoading = false
//    }

//    func deleteTransaction(_ transaction: Transaction) async {
//        guard let userId = authManager.userId else {
//            errorMessage = "User not authenticated"
//            return
//        }
//
//        isLoading = true
//
//        do {
//            try await db.collection("users")
//                .document(userId)
//                .collection("transactions_data")
//                .document(transaction.id)
//                .delete()
//            await loadTransactionsForCurrentlyShownTimePeriod()
//        } catch {
//            errorMessage = "Failed to delete transaction: \(error.localizedDescription)"
//        }
//
//        isLoading = false
//    }

    func loadTransactions(startDate: Date, endDate: Date) async {
        if reloadTransactions {
            self.transactionSummary = nil
            self.resetReloadTransaction()
        }

        guard let userId = authManager.userId else { return }

        isLoading = true

        // Remove existing listener
        removeListener()

        // Query with date range
        listenerRegistration = db.collection("users")
            .document(userId)
            .collection("transactions_data")
            .whereField("date", isGreaterThanOrEqualTo: startDate.timeIntervalSince1970)
            .whereField("date", isLessThanOrEqualTo: endDate.timeIntervalSince1970)
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to load transactions: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                    return
                }

                guard let documents = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self.transactions = []
                        self.isLoading = false
                    }
                    return
                }

                Task {
                    let loadedTransactions = await self.parseTransactions(from: documents)
                    await MainActor.run {
                        self.transactions = loadedTransactions
                        self.transactionSummary = self.getTransactionSummary()
                        self.isLoading = false
                    }
                }
            }
    }

    private func parseTransactions(from documents: [QueryDocumentSnapshot]) async -> [Transaction] {
        var parsedTransactions: [Transaction] = []

        for document in documents {
            let data = document.data()

            guard let idString = data["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let typeString = data["type"] as? String,
                  let type = TransactionType(rawValue: typeString),
                  let categoryString = data["category"] as? String,
                  let category = TransactionCategory(rawValue: categoryString),
                  let title = data["title"] as? String,
                  let amount = data["amount"] as? Double else {
                continue
            }

            // Parse date
            let date: Date
            if let timestamp = data["date"] as? Timestamp {
                date = timestamp.dateValue()
            } else {
                date = Date()
            }

            // Parse items
            let items: [TransactionItem] = (data["items"] as? [[String: Any]])?.compactMap { itemData in
                guard let name = itemData["name"] as? String,
                      let quantity = itemData["quantity"] as? Double,
                      let unitPrice = itemData["unitPrice"] as? Double else {
                    return nil
                }
                return TransactionItem(name: name, quantity: quantity, unitPrice: unitPrice)
            } ?? []

            let transaction = Transaction(
                id: idString,
                type: type,
                category: category,
                amount: amount,
                date: date.timeIntervalSince1970,
                title: title,
                notes: data["notes"] as? String,
                items: items,
                location: data["location"] as? String,
                tags: data["tags"] as? [String] ?? []
            )

            parsedTransactions.append(transaction)
        }

        return parsedTransactions
    }

    // MARK: - Query Operations

    func getTransactions(with filters: TransactionFilters) -> [Transaction] {
        return filters.apply(to: transactions)
    }

    func getTransactionSummary() -> TransactionSummary {
        return TransactionSummary(transactions: transactions)
    }

    func searchTransactions(query: String) -> [Transaction] {
        let lowercasedQuery = query.lowercased()
        return transactions.filter { transaction in
            transaction.title.lowercased().contains(lowercasedQuery) ||
            transaction.notes?.lowercased().contains(lowercasedQuery) == true ||
            transaction.items.contains { $0.name.lowercased().contains(lowercasedQuery) }
        }
    }

    // MARK: - Statistics

    func getTotalBalance() -> Double {
        let summary = getTransactionSummary()
        return summary.totalBalance
    }

    func getTotalIncome() -> Double {
        let summary = getTransactionSummary()
        return summary.totalIncome
    }

    func getTotalExpenses() -> Double {
        let summary = getTransactionSummary()
        return summary.totalExpenses
    }

    func getExpensesByCategory() -> [TransactionCategory: Double] {
        let summary = getTransactionSummary()
        return summary.expensesByCategory()
    }

    // MARK: - Data Export/Import

    func exportData() async -> Data? {
        let exportData = transactions.map { $0.toFirestoreData() }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            return jsonData
        } catch {
            errorMessage = "Failed to export data: \(error.localizedDescription)"
            return nil
        }
    }

    func importData(_ jsonData: Data) async {
        do {
            guard let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
                throw NSError(domain: "ImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
            }

            for transactionData in jsonArray {
                if let transaction = Transaction.fromFirestoreData(transactionData) {
                    await addTransaction(transaction)
                }
            }
        } catch {
            errorMessage = "Failed to import data: \(error.localizedDescription)"
        }
    }

    // MARK: - Helper Methods

    private func removeListener() {
        listenerRegistration?.remove()
        listenerRegistration = nil
    }

    func clearError() {
        errorMessage = nil
    }

    deinit {
//        removeListener()
    }
}
