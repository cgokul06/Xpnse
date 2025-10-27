//
//  FirebaseTransactionManager.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation
import FirebaseFirestore
import Combine

struct CustomError {
    let code: Int
    let message: String
}

enum FirebaseErrorType: Error {
    case unauthorized
    case contextError
    case customError(CustomError)
    case noDocumentFound
}

final class FirebaseTransactionManager {
    private static var _shared: FirebaseTransactionManager?
    private let authManager: FirebaseAuthManager

    private init(authManager: FirebaseAuthManager) {
        self.authManager = authManager
    }

    static func setup(authManager: FirebaseAuthManager) {
        if _shared == nil {
            _shared = FirebaseTransactionManager(authManager: authManager)
        }
    }

    // Static computed property to access the shared instance
    static var shared: FirebaseTransactionManager {
        guard let instance = _shared else {
            fatalError("MySingleton has not been initialized. Call setup(with:) first.")
        }
        return instance
    }

    static func reset() {
        self._shared = nil
    }

    private let db = Firestore.firestore()


    // MARK: - CRUD Operations

    func addTransaction(_ transaction: Transaction) async {
        guard let userId = authManager.userId else {
//            errorMessage = "User not authenticated"
            return
        }

//        isLoading = true

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
//            self.reloadTransactions = true
        } catch {
//            errorMessage = "Failed to add transaction: \(error.localizedDescription)"
        }

//        isLoading = false
    }

    func updateTransaction(_ transaction: Transaction) async {
        guard let userId = authManager.userId else {
//            errorMessage = "User not authenticated"
            return
        }

//        isLoading = true

        do {
            var transactionData = transaction.toFirestoreData()
            transactionData["updatedAt"] = FieldValue.serverTimestamp()

            try await db.collection("users")
                .document(userId)
                .collection("transactions_data")
                .document(transaction.id)
                .setData(transactionData, merge: true)

//            await loadTransactionsForCurrentlyShownTimePeriod()
        } catch {
//            errorMessage = "Failed to update transaction: \(error.localizedDescription)"
        }

//        isLoading = false
    }

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

    func loadTransactions(
        startDate: Date,
        endDate: Date,
        range: CalendarComparison
    ) async throws -> TransactionSummary {
        guard let userId = authManager.userId else {
            throw FirebaseErrorType.unauthorized
        }

        // Query with date range
        let snapshot = try? await db.collection("users")
            .document(userId)
            .collection("transactions_data")
            .whereField("date", isGreaterThanOrEqualTo: startDate.timeIntervalSince1970)
            .whereField("date", isLessThanOrEqualTo: endDate.timeIntervalSince1970)
            .order(by: "date", descending: true)
            .getDocuments()

        guard let snapshot else {
            throw FirebaseErrorType.noDocumentFound
        }

        let loadedTransactions = await self.parseTransactions(from: snapshot.documents)
        return TransactionSummary(
            transactions: loadedTransactions,
            startDate: startDate,
            endDate: endDate,
            range: range
        )
    }

    private func parseTransactions(from documents: [QueryDocumentSnapshot]) async -> [Transaction] {
        var parsedTransactions: [Transaction] = []

        for document in documents {
            let data = document.data()

            guard let idString = data["id"] as? String,
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
            if let timestamp = data["date"] as? Double {
                date = Date(timeIntervalSince1970: timestamp)
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
}
