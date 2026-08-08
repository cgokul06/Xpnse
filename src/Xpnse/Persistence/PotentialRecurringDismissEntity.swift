//
//  PotentialRecurringDismissEntity.swift
//  Xpnse
//

import Foundation
import SwiftData

@Model
final class PotentialRecurringDismissEntity {
    @Attribute(.unique) var id: String
    var transactionId: String
    var fingerprint: String
    var dismissedAt: Date
    var updatedAt: Date

    init(from record: PotentialRecurringDismissRecord) {
        self.id = record.id
        self.transactionId = record.transactionId
        self.fingerprint = record.fingerprint
        self.dismissedAt = record.dismissedAt
        self.updatedAt = record.updatedAt
    }

    func update(from record: PotentialRecurringDismissRecord) {
        self.transactionId = record.transactionId
        self.fingerprint = record.fingerprint
        self.dismissedAt = record.dismissedAt
        self.updatedAt = record.updatedAt
    }

    func toDomain() -> PotentialRecurringDismissRecord {
        PotentialRecurringDismissRecord(
            id: id,
            transactionId: transactionId,
            fingerprint: fingerprint,
            dismissedAt: dismissedAt,
            updatedAt: updatedAt
        )
    }
}
