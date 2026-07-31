//
//  FeedbackUploadService.swift
//  Xpnse
//

import Foundation
import FirebaseFirestore
import UIKit

struct FeedbackPayload {
    let type: String
    let message: String
    let snapshot: ReviewStateSnapshot
}

enum FeedbackUploadService {
    static func upload(_ payload: FeedbackPayload) async throws {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? payload.snapshot.appVersion
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let device = await MainActor.run { UIDevice.current.model }
        let systemVersion = await MainActor.run { UIDevice.current.systemVersion }

        let data: [String: Any] = [
            "type": payload.type,
            "message": payload.message,
            "createdAt": FieldValue.serverTimestamp(),
            "appVersion": short,
            "buildNumber": build,
            "deviceModel": device,
            "iOSVersion": systemVersion,
            "locale": Locale.current.identifier,
            "transactionsCount": payload.snapshot.lifetimeTransactions,
            "launchCount": payload.snapshot.launchCount,
            "daysSinceInstall": payload.snapshot.daysSinceInstall,
            "receiptScans": payload.snapshot.lifetimeReceiptScans,
            "anonymousUserId": AnonymousIdentity.userId
        ]

        try await Firestore.firestore().collection("feedback").document().setData(data)
    }
}
