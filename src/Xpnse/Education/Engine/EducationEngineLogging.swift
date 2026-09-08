//
//  EducationEngineLogging.swift
//  Xpnse
//

import Foundation

protocol EducationEngineLogging: Sendable {
    func log(_ message: String)
}

struct NoOpEducationEngineLogger: EducationEngineLogging {
    func log(_ message: String) {}
}

final class CollectingEducationEngineLogger: EducationEngineLogging, @unchecked Sendable {
    private let lock = NSLock()
    private var messages: [String] = []

    func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        messages.append(message)
    }

    func recordedMessages() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return messages
    }

    func contains(_ substring: String) -> Bool {
        recordedMessages().contains { $0.contains(substring) }
    }
}

#if DEBUG
struct PrintEducationEngineLogger: EducationEngineLogging {
    func log(_ message: String) {
        print("[EducationEngine] \(message)")
    }
}
#endif
