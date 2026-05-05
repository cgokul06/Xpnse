//
//  ExportImportService.swift
//  Xpnse
//
//  Created by Gokul C on 04/05/26.
//

import Foundation

enum ExportImportError: Error {
    case invalidBackup
}

struct ExportImportService {
    private let transactionRepository: TransactionRepository
    private let recurringRepository: RecurringRepository

    init(
        transactionRepository: TransactionRepository = SwiftDataTransactionRepository.shared,
        recurringRepository: RecurringRepository = SwiftDataRecurringRepository.shared
    ) {
        self.transactionRepository = transactionRepository
        self.recurringRepository = recurringRepository
    }

    func exportAllData() async throws -> String {
        let payload = BackupPayload(
            schemaVersion: 1,
            exportedAt: Date(),
            transactions: try await transactionRepository.fetchAll(),
            recurringTransactions: try await recurringRepository.fetchAll()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    func importAllData(_ text: String) async throws {
        guard let data = text.data(using: .utf8) else {
            throw ExportImportError.invalidBackup
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload: BackupPayload
        do {
            payload = try decoder.decode(BackupPayload.self, from: data)
        } catch {
            throw ExportImportError.invalidBackup
        }

        for transaction in payload.transactions {
            try await transactionRepository.update(transaction)
        }
        for recurring in payload.recurringTransactions {
            try await recurringRepository.upsert(recurring)
        }
    }
}

private struct BackupPayload: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let transactions: [Transaction]
    let recurringTransactions: [RecurringTransaction]
}
