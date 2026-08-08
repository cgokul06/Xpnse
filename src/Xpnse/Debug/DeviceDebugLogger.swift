//
//  DeviceDebugLogger.swift
//  Xpnse
//
//  DEBUG-only on-device NDJSON log with 3-day retention and share export.
//

import Foundation

/// Append-only debug log for investigating issues off-Mac (share from Settings).
/// No-ops in Release builds.
enum DeviceDebugLogger {
    static func log(
        _ message: String,
        category: String = "general",
        data: [String: Any] = [:]
    ) {
        #if DEBUG
        Impl.append(message: message, category: category, data: data)
        #endif
    }

    /// Snapshot of the current log file for sharing (nil if empty / unavailable).
    static func prepareShareURL() -> URL? {
        #if DEBUG
        return Impl.prepareShareURL()
        #else
        return nil
        #endif
    }

    static func clear() {
        #if DEBUG
        Impl.clear()
        #endif
    }

    static var approximateByteCount: Int {
        #if DEBUG
        return Impl.approximateByteCount
        #else
        return 0
        #endif
    }

    #if DEBUG
    private enum Impl {
        private static let fileName = "snapledger-device-debug.ndjson"
        private static let retentionDays = 3
        private static let queue = DispatchQueue(label: "com.snapledger.device-debug-log")
        private static var writesSincePurge = 0

        private static var logURL: URL {
            let fm = FileManager.default
            let base = (try? fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return base.appendingPathComponent(fileName)
        }

        static var approximateByteCount: Int {
            queue.sync {
                (try? FileManager.default.attributesOfItem(atPath: logURL.path)[.size] as? NSNumber)?.intValue ?? 0
            }
        }

        static func append(message: String, category: String, data: [String: Any]) {
            queue.async {
                purgeIfNeeded()
                var payload: [String: Any] = [
                    "ts": Int(Date().timeIntervalSince1970 * 1000),
                    "category": category,
                    "message": message
                ]
                if !data.isEmpty {
                    payload["data"] = data
                }
                guard JSONSerialization.isValidJSONObject(payload),
                      let json = try? JSONSerialization.data(withJSONObject: payload),
                      var line = String(data: json, encoding: .utf8)
                else { return }
                line.append("\n")
                let url = logURL
                if FileManager.default.fileExists(atPath: url.path),
                   let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    try? handle.seekToEnd()
                    if let bytes = line.data(using: .utf8) {
                        try? handle.write(contentsOf: bytes)
                    }
                } else {
                    try? line.data(using: .utf8)?.write(to: url, options: .atomic)
                }
                writesSincePurge += 1
            }
        }

        static func prepareShareURL() -> URL? {
            queue.sync {
                purgeIfNeeded(force: true)
                let source = logURL
                guard FileManager.default.fileExists(atPath: source.path),
                      let data = try? Data(contentsOf: source),
                      !data.isEmpty
                else { return nil }

                let stamp = ISO8601DateFormatter().string(from: Date())
                    .replacingOccurrences(of: ":", with: "-")
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent("snapledger-debug-\(stamp).ndjson")
                try? data.write(to: dest, options: .atomic)
                return dest
            }
        }

        static func clear() {
            queue.sync {
                try? FileManager.default.removeItem(at: logURL)
                writesSincePurge = 0
            }
        }

        private static func purgeIfNeeded(force: Bool = false) {
            if !force && writesSincePurge > 0 && writesSincePurge < 40 { return }
            writesSincePurge = 0

            let url = logURL
            guard let raw = try? String(contentsOf: url, encoding: .utf8), !raw.isEmpty else { return }

            let cutoffMs = Int(Date().addingTimeInterval(-Double(retentionDays) * 24 * 3600)
                .timeIntervalSince1970 * 1000)

            let kept = raw.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line -> String? in
                guard let data = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let ts = obj["ts"] as? Int
                else { return String(line) }
                return ts >= cutoffMs ? String(line) : nil
            }

            let rewritten = kept.isEmpty ? "" : kept.joined(separator: "\n") + "\n"
            try? rewritten.data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }
    #endif
}
