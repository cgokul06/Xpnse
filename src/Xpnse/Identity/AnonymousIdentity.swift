//
//  AnonymousIdentity.swift
//  Xpnse
//

import Foundation

/// Stable anonymous identifiers for analytics, feature gates, and future linking.
///
/// - `userId`: Keychain-backed; generated once; survives relaunches (and often reinstalls).
/// - `installationId`: UserDefaults-backed; identifies this install only.
enum AnonymousIdentity {
    private static let userIdKeychainAccount = "anonymousUserId"
    private static let lock = NSLock()
    private static var cachedUserId: String?
    private static var cachedInstallationId: String?

    /// Stable anonymous user id. Created once and stored in Keychain.
    static var userId: String {
        lock.lock()
        defer { lock.unlock() }

        if let cachedUserId {
            return cachedUserId
        }

        if let existing = KeychainStore.string(forKey: userIdKeychainAccount), !existing.isEmpty {
            cachedUserId = existing
            return existing
        }

        let created = UUID().uuidString.lowercased()
        _ = KeychainStore.setString(created, forKey: userIdKeychainAccount)
        cachedUserId = created
        return created
    }

    /// Installation-scoped id. Regenerated after uninstall when UserDefaults is cleared.
    static var installationId: String {
        lock.lock()
        defer { lock.unlock() }

        if let cachedInstallationId {
            return cachedInstallationId
        }

        if let existing = UserDefaultsHelper.shared.string(forKey: .installationId), !existing.isEmpty {
            cachedInstallationId = existing
            return existing
        }

        let created = UUID().uuidString.lowercased()
        UserDefaultsHelper.shared.set(created, forKey: .installationId)
        cachedInstallationId = created
        return created
    }

    /// Warm both IDs and attach `userId` to Firebase Analytics.
    static func bootstrap() {
        let resolvedUserId = userId
        _ = installationId
        AppAnalytics.configureUserId(resolvedUserId)

        #if DEBUG
        print(
            "AnonymousIdentity bootstrap userId=\(resolvedUserId) installationId=\(installationId)"
        )
        #endif
    }
}
