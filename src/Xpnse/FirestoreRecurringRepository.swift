import Foundation
import FirebaseFirestore

/// Protocol defining operations for recurring transactions repository.
public protocol RecurringRepository {
    /// Fetches all recurring transactions for the given userId.
    func fetchAll(for userId: String) async throws -> [RecurringTransaction]

    /// Inserts or updates a recurring transaction for the given userId.
    func upsert(_ item: RecurringTransaction, for userId: String) async throws

    /// Deletes a recurring transaction by id for the given userId.
    func delete(id: UUID, for userId: String) async throws
}

/// Firestore-backed implementation of `RecurringRepository`.
public final class FirestoreRecurringRepository: RecurringRepository {
    public static let shared: FirestoreRecurringRepository = FirestoreRecurringRepository()
    private let db = Firestore.firestore()

    /// Returns the collection reference for recurring transactions of a user.
    /// - Parameter userId: The ID of the user.
    /// - Returns: Firestore `CollectionReference`.
    private func collection(for userId: String) -> CollectionReference {
        db.collection("users").document(userId).collection("recurringTransactions")
    }

    public func fetchAll(for userId: String) async throws -> [RecurringTransaction] {
        let snapshot = try await collection(for: userId).getDocuments()
        var results: [RecurringTransaction] = []
        for doc in snapshot.documents {
            let data = doc.data()
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            let item = try JSONDecoder().decode(RecurringTransaction.self, from: jsonData)
            results.append(item)
        }
        return results
    }

    public func upsert(_ item: RecurringTransaction, for userId: String) async throws {
        let ref = collection(for: userId).document(item.id.uuidString)
        let jsonData = try JSONEncoder().encode(item)
        let dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] ?? [:]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setData(dict, merge: true) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    public func delete(id: UUID, for userId: String) async throws {
        let ref = collection(for: userId).document(id.uuidString)
        try await ref.delete()
    }
}
