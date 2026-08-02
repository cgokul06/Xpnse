//
//  AgentDebugLog.swift
//  Xpnse
//
//  Shared debug-session logger. Prefer device builds: POSTs NDJSON to the
//  Cursor ingest server on the Mac LAN. Also tries localhost (Simulator) and
//  a host filesystem path when available.
//

import Foundation

enum AgentDebugLog {
    /// Cursor debug session id — update when starting a new debug session.
    private static let sessionId = "9c59e6"

    /// Host filesystem path (Simulator / Mac Catalyst only).
    private static let logPath = "/Users/gokulc/Desktop/Xpnse/.cursor/debug-9c59e6.log"

    /// Mac LAN IP for physical-device ingest. Update if your Mac's IP changes.
    private static let hostLANIP = "192.168.68.51"
    private static let ingestPath = "/ingest/1c5235bd-4792-4659-9160-b047fca07c3d"

    private static var ingestURLs: [URL] {
        [
            URL(string: "http://\(hostLANIP):7603\(ingestPath)")!,
            URL(string: "http://127.0.0.1:7603\(ingestPath)")!
        ]
    }

    static func log(
        _ hypothesisId: String,
        _ location: String,
        _ message: String,
        data: [String: Any] = [:],
        runId: String = "pre-fix"
    ) {
        var payload: [String: Any] = [
            "sessionId": sessionId,
            "runId": runId,
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if !data.isEmpty {
            payload["data"] = data
        }
        guard JSONSerialization.isValidJSONObject(payload),
              let json = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: json, encoding: .utf8) else { return }

        // #region agent log
        try? (line + "\n").append(toFileAtPath: logPath)

        for url in ingestURLs {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(sessionId, forHTTPHeaderField: "X-Debug-Session-Id")
            request.httpBody = json
            request.timeoutInterval = 2
            URLSession.shared.dataTask(with: request).resume()
        }
        // #endregion
    }
}

private extension String {
    func append(toFileAtPath path: String) throws {
        let url = URL(fileURLWithPath: path)
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        if let data = data(using: .utf8) {
            try handle.write(contentsOf: data)
        }
    }
}
