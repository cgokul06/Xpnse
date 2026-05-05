//
//  FirebaseTransactionManager.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import Foundation
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
    static let shared = FirebaseTransactionManager()

    private let transactionRepository: TransactionRepository
    private let recurringTransactionManager: RecurringTransactionManager

    private init(
        transactionRepository: TransactionRepository = SwiftDataTransactionRepository.shared,
        recurringTransactionManager: RecurringTransactionManager = RecurringTransactionManager()
    ) {
        self.transactionRepository = transactionRepository
        self.recurringTransactionManager = recurringTransactionManager
    }

    func processRecurringTransactions() {
        Task {
            await self.recurringTransactionManager.loadAndProcess(sink: self)
        }
    }

    private var listeners: Set<String> = []
    var changesPublisher: AnyPublisher<Void, Never> {
        transactionRepository.changesPublisher
    }

    static func setup(authManager: FirebaseAuthManager) {
        // Kept for call-site compatibility while removing login dependencies.
        _ = authManager
    }

    static func reset() {
        // No-op for local SwiftData-backed storage.
    }


    // MARK: - CRUD Operations

    func addTransaction(_ transaction: Transaction) async {
        do {
            try await transactionRepository.add(transaction)
        } catch {
            print("Failed to add transaction: \(error.localizedDescription)")
        }
    }

    func updateTransaction(_ transaction: Transaction) async {
        do {
            try await transactionRepository.update(transaction)
        } catch {
            print("Failed to update transaction: \(error.localizedDescription)")
        }
    }

        func deleteTransaction(_ transaction: Transaction) async {
            do {
                try await transactionRepository.delete(transaction)
            } catch {
                print("Failed to delete transaction: \(error.localizedDescription)")
            }
        }

    func loadTransactions(
        startDate: Date,
        endDate: Date,
        range: CalendarComparison,
        onUpdate: @escaping (Result<TransactionSummary, FirebaseErrorType>) -> Void
    ) async throws {
        let key = "\(startDate.timeIntervalSince1970)-\(endDate.timeIntervalSince1970)"
        removeListener(for: key)
        listeners.insert(key)
        let transactions = try await transactionRepository.fetch(startDate: startDate, endDate: endDate)
        var parsedTransactions: [Date: [Transaction]] = [:]

        for transaction in transactions {
            let date = Date(timeIntervalSince1970: transaction.date)
            let dateOfTransaction = Calendar.current.startOfDay(for: date)
            parsedTransactions[dateOfTransaction, default: []].append(transaction)
        }

        let summary = TransactionSummary(
            transactions: parsedTransactions,
            startDate: startDate,
            endDate: endDate,
            range: range
        )
        onUpdate(.success(summary))
    }

    // MARK: - Remove Specific Listener
    func removeListener(for key: String) {
        listeners.remove(key)
    }

    // MARK: - Remove All Listeners
    func removeAllListeners() {
        listeners = []
    }

    func clearAll() async {
        do {
            try await transactionRepository.clearAll()
            try await SwiftDataRecurringRepository.shared.clearAll()
        } catch {
            print("Failed to clear local data: \(error.localizedDescription)")
        }
    }
}

extension FirebaseTransactionManager: TransactionSink {}
