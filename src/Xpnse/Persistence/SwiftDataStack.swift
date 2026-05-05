//
//  SwiftDataStack.swift
//  Xpnse
//
//  Created by Gokul C on 04/05/26.
//

import Foundation
import SwiftData

enum SwiftDataStack {
    static let sharedContainer: ModelContainer = {
        let schema = Schema([
            TransactionEntity.self,
            RecurringTransactionEntity.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }()
}
