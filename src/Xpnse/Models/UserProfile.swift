//
//  UserProfile.swift
//  Xpnse
//
//  Created by Assistant on 26/09/25.
//

import Foundation

/// Represents a user profile document stored in Firestore at `users/{uid}`
struct UserProfile: Identifiable, Codable, Hashable {
    // Use `uid` as the identity
    var id: String { uid }

    let uid: String
    var email: String?
    var displayName: String?
    var photoURL: String?
    var providerIds: [String]
    var isEmailVerified: Bool

    /// Preferred currency code (e.g., "USD", "INR")
    var currency: String

    // MARK: - Firestore Conversion

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "uid": uid,
            "providerIds": providerIds,
            "isEmailVerified": isEmailVerified,
            "currency": currency
        ]

        if let email = email { data["email"] = email }
        if let displayName = displayName { data["displayName"] = displayName }
        if let photoURL = photoURL { data["photoURL"] = photoURL }

        return data
    }
}


