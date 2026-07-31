//
//  AppStoreReviewRequester.swift
//  Xpnse
//

import StoreKit
import UIKit

enum AppStoreReviewRequester {
    @MainActor
    static func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        AppStore.requestReview(in: scene)
    }
}
