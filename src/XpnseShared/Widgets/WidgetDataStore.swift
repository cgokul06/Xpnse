//
//  WidgetDataStore.swift
//  Xpnse
//

import Foundation

enum WidgetDataStore {
    private static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupConstants.identifier
        )
    }

    private static var snapshotURL: URL? {
        containerURL?.appendingPathComponent(AppGroupConstants.snapshotFileName)
    }

    static func save(_ snapshot: WidgetMonthSnapshot) throws {
        guard let snapshotURL else {
            throw WidgetDataStoreError.appGroupUnavailable
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: snapshotURL, options: .atomic)
    }

    static func load() -> WidgetMonthSnapshot? {
        guard let snapshotURL,
              let data = try? Data(contentsOf: snapshotURL)
        else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(WidgetMonthSnapshot.self, from: data)
        } catch {
            print("Widget snapshot decode failed: \(error.localizedDescription)")
            return nil
        }
    }
}

enum WidgetDataStoreError: Error {
    case appGroupUnavailable
}
