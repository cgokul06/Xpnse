//
//  SharedImageInboxStore.swift
//  XpnseShared
//

import Foundation

enum SharedImageInboxStore {
    private static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.identifier
        )
    }

    private static var inboxURL: URL? {
        containerURL?.appendingPathComponent(AppGroupConstants.sharedImageInboxFileName)
    }

    static func write(_ data: Data) throws {
        guard let inboxURL else {
            throw SharedImageInboxStoreError.appGroupUnavailable
        }
        guard !data.isEmpty else {
            throw SharedImageInboxStoreError.emptyImage
        }
        try data.write(to: inboxURL, options: .atomic)
    }

    static func read() -> Data? {
        guard let inboxURL,
              let data = try? Data(contentsOf: inboxURL),
              !data.isEmpty
        else {
            return nil
        }
        return data
    }

    static func clear() {
        guard let inboxURL else { return }
        try? FileManager.default.removeItem(at: inboxURL)
    }

    static var hasContent: Bool {
        guard let inboxURL else { return false }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: inboxURL.path),
              let size = attrs[.size] as? NSNumber
        else {
            return false
        }
        return size.intValue > 0
    }
}

enum SharedImageInboxStoreError: Error {
    case appGroupUnavailable
    case emptyImage
}
