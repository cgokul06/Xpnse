//
//  SharedTextInboxStore.swift
//  XpnseShared
//

import Foundation

struct SharedTextInboxPayload: Codable, Equatable {
    var text: String
    var createdAt: TimeInterval
}

enum SharedTextInboxStore {
    private static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.identifier
        )
    }

    private static var inboxURL: URL? {
        containerURL?.appendingPathComponent(AppGroupConstants.sharedTextInboxFileName)
    }

    static func write(_ text: String) throws {
        guard let inboxURL else {
            throw SharedTextInboxStoreError.appGroupUnavailable
        }
        let payload = SharedTextInboxPayload(
            text: text,
            createdAt: Date().timeIntervalSince1970
        )
        let data = try JSONEncoder().encode(payload)
        try data.write(to: inboxURL, options: .atomic)
    }

    static func read() -> SharedTextInboxPayload? {
        guard let inboxURL,
              let data = try? Data(contentsOf: inboxURL)
        else {
            return nil
        }
        return try? JSONDecoder().decode(SharedTextInboxPayload.self, from: data)
    }

    static func clear() {
        guard let inboxURL else { return }
        try? FileManager.default.removeItem(at: inboxURL)
    }

    static var hasContent: Bool {
        read()?.text.isEmpty == false
    }
}

enum SharedTextInboxStoreError: Error {
    case appGroupUnavailable
}
