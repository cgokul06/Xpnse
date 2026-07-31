//
//  CooldownPolicy.swift
//  Xpnse
//

import Foundation

enum CooldownStatus: Equatable {
    case allowed
    case blocked(reason: String)
}

enum CooldownPolicy {
    static let dismissCooldownDays = 30

    static func evaluate(
        state: ReviewState,
        now: Date,
        currentVersion: String
    ) -> CooldownStatus {
        if state.appStoreOpened {
            return .blocked(reason: "app_store_opened")
        }

        // Feedback submitted: wait until the next app version.
        if state.feedbackSubmitted,
           let lastVersion = state.lastPromptVersion,
           lastVersion == currentVersion {
            return .blocked(reason: "awaiting_next_version")
        }

        if state.feedbackSubmitted,
           let lastVersion = state.lastPromptVersion,
           lastVersion != currentVersion {
            return .allowed
        }

        if let lastPrompt = state.lastPromptDate,
           state.reviewRequested || state.dismissCount > 0 {
            let days = Calendar.current.dateComponents([.day], from: lastPrompt, to: now).day ?? 0
            if days < dismissCooldownDays {
                return .blocked(reason: "dismiss_cooldown")
            }
        }

        return .allowed
    }
}
