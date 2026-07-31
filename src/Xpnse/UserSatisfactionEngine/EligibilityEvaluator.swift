//
//  EligibilityEvaluator.swift
//  Xpnse
//

import Foundation

enum EligibilityFailure: String {
    case daysSinceInstall
    case launchCount
    case lifetimeTransactions
    case cooldown
    case appStoreOpened
    case criticalErrorThisSession
}

enum EligibilityResult: Equatable {
    case eligible
    case ineligible(EligibilityFailure)
}

enum EligibilityEvaluator {
    static let minimumDaysSinceInstall = 7
    static let minimumLaunchCount = 8
    static let minimumLifetimeTransactions = 20

    static func evaluate(
        state: ReviewState,
        now: Date,
        currentVersion: String,
        criticalErrorThisSession: Bool
    ) -> EligibilityResult {
        if state.appStoreOpened {
            return .ineligible(.appStoreOpened)
        }
        if criticalErrorThisSession {
            return .ineligible(.criticalErrorThisSession)
        }

        let daysSinceInstall = Calendar.current.dateComponents(
            [.day],
            from: state.installationDate,
            to: now
        ).day ?? 0
        if daysSinceInstall < minimumDaysSinceInstall {
            return .ineligible(.daysSinceInstall)
        }
        if state.launchCount < minimumLaunchCount {
            return .ineligible(.launchCount)
        }
        if state.lifetimeTransactions < minimumLifetimeTransactions {
            return .ineligible(.lifetimeTransactions)
        }

        switch CooldownPolicy.evaluate(state: state, now: now, currentVersion: currentVersion) {
        case .allowed:
            return .eligible
        case .blocked:
            return .ineligible(.cooldown)
        }
    }
}
