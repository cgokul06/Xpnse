//
//  AppLockController.swift
//  Xpnse
//

import Foundation
import LocalAuthentication
import Observation
import Security
import SwiftUI
import UIKit

@MainActor
@Observable
final class AppLockController {
    static let shared = AppLockController()

    static let unlockGraceInterval: TimeInterval = 3600

    private(set) var isEnabled: Bool
    private(set) var isLocked: Bool
    private(set) var isAuthenticating = false
    private(set) var showsPrivacyCover = false
    private(set) var promoShown: Bool

    /// Set when the scene enters background; consumed on next activation to decide lock.
    /// Avoids Face ID's inactive↔active cycle from re-locking mid-unlock.
    @ObservationIgnored private var shouldLockWhenActive = false

    @ObservationIgnored private let defaults: UserDefaultsHelper
    @ObservationIgnored private var privacyWindow: UIWindow?

    private init(defaults: UserDefaultsHelper = .shared) {
        self.defaults = defaults
        let enabled = defaults.bool(forKey: .appLockEnabled)
        self.isEnabled = enabled
        self.promoShown = defaults.bool(forKey: .appLockPromoShown)
        self.isLocked = enabled && !Self.isWithinGrace(defaults: defaults)
    }

    // MARK: - Soft-sell eligibility

    /// Core eligibility excluding idle timing (transaction count, never shown, lock off).
    var meetsPromoContentEligibility: Bool {
        guard !isEnabled else { return false }
        guard !promoShown else { return false }
        guard UserSatisfactionEngine.shared.lifetimeTransactionsCount >= 1 else { return false }
        return canEvaluateDeviceOwnerAuthentication
    }

    var canOfferSoftPrompt: Bool {
        meetsPromoContentEligibility
            && UserEngagementCoordinator.shared.canPresentNonCriticalUI
    }

    var canEvaluateDeviceOwnerAuthentication: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    // MARK: - Persistence helpers

    private var lastUnlockAt: Date? {
        get {
            guard defaults.object(forKey: .appLockLastUnlockAt) != nil else { return nil }
            return Date(timeIntervalSince1970: defaults.double(forKey: .appLockLastUnlockAt))
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: .appLockLastUnlockAt)
            } else {
                defaults.remove(forKey: .appLockLastUnlockAt)
            }
        }
    }

    private var isWithinGracePeriod: Bool {
        Self.isWithinGrace(defaults: defaults)
    }

    private static func isWithinGrace(defaults: UserDefaultsHelper) -> Bool {
        guard defaults.object(forKey: .appLockLastUnlockAt) != nil else { return false }
        let last = Date(timeIntervalSince1970: defaults.double(forKey: .appLockLastUnlockAt))
        return Date().timeIntervalSince(last) < unlockGraceInterval
    }

    // MARK: - Lock lifecycle

    /// Call from `sceneDidEnterBackground` only — not from resign-active (Face ID uses that).
    func noteDidEnterBackground() {
        guard isEnabled else { return }
        if !isWithinGracePeriod {
            shouldLockWhenActive = true
        }
        showPrivacyCoverIfNeeded()
    }

    func evaluateLockStateOnActivation() {
        hidePrivacyCover()
        guard isEnabled else {
            isLocked = false
            shouldLockWhenActive = false
            return
        }
        // Face ID / passcode UI briefly resigns active; don't re-lock while authenticating
        // or on the become-active that follows a successful unlock without a real background.
        if isAuthenticating { return }

        if shouldLockWhenActive {
            shouldLockWhenActive = false
            isLocked = !isWithinGracePeriod
            return
        }

        // Backgrounding while still in grace leaves shouldLockWhenActive false.
        // If the process stays suspended past grace, re-check here on activation.
        if !isWithinGracePeriod {
            isLocked = true
        }
    }

    func markUnlocked() {
        lastUnlockAt = Date()
        isLocked = false
        shouldLockWhenActive = false
    }

    @discardableResult
    func unlockWithBiometricsOrPasscode(
        reason: String = L10n.tr("app_lock.unlock_reason")
    ) async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await authenticateWithBiometricsThenPasscode(reason: reason)
            if success {
                markUnlocked()
            }
            return success
        } catch {
            return false
        }
    }

    /// Enable or disable app lock. Authentication is required for both directions.
    @discardableResult
    func setEnabled(_ enabled: Bool) async -> Bool {
        let reason = enabled
            ? L10n.tr("app_lock.enable_reason")
            : L10n.tr("app_lock.disable_reason")

        guard !isAuthenticating else { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await authenticateWithBiometricsThenPasscode(reason: reason)
            guard success else { return false }

            isEnabled = enabled
            defaults.set(enabled, forKey: .appLockEnabled)

            if enabled {
                markUnlocked()
            } else {
                lastUnlockAt = nil
                isLocked = false
                hidePrivacyCover()
            }
            return true
        } catch {
            return false
        }
    }

    /// Face ID / Touch ID with system passcode fallback.
    /// - Prefer a single `.deviceOwnerAuthentication` sheet (passcode button stays in-system).
    /// - If the user taps "Use Passcode" (`userFallback`) or biometry locks out, present
    ///   a passcode-only challenge so Face ID does not run again.
    private func authenticateWithBiometricsThenPasscode(reason: String) async throws -> Bool {
        do {
            return try await evaluateDeviceOwnerAuthentication(reason: reason)
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel, .systemCancel:
                throw error
            case .userFallback, .biometryLockout:
                // Face ID sheet is dismissing; wait so the passcode UI can present cleanly.
                try await Task.sleep(for: .milliseconds(450))
                return try await evaluateDevicePasscodeOnly(reason: reason)
            case .authenticationFailed:
                try await Task.sleep(for: .milliseconds(450))
                return try await evaluateDeviceOwnerAuthentication(reason: reason)
            default:
                throw error
            }
        }
    }

    private func makeAuthContext() -> LAContext {
        let context = LAContext()
        context.localizedCancelTitle = L10n.tr("common.cancel")
        context.localizedFallbackTitle = L10n.tr("app_lock.use_passcode")
        return context
    }

    private func evaluateDeviceOwnerAuthentication(reason: String) async throws -> Bool {
        let context = makeAuthContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? LAError(.authenticationFailed)
        }
        return try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        )
    }

    /// Device passcode only — used after the user explicitly chooses passcode or Face ID lockout.
    private func evaluateDevicePasscodeOnly(reason: String) async throws -> Bool {
        var cfError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .devicePasscode,
            &cfError
        ) else {
            if let cfError {
                throw cfError.takeRetainedValue() as Error
            }
            throw LAError(.authenticationFailed)
        }

        let context = makeAuthContext()
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluateAccessControl(
                accessControl,
                operation: .useItem,
                localizedReason: reason
            ) { success, error in
                if success {
                    continuation.resume(returning: true)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func markPromoShown() {
        guard !promoShown else { return }
        promoShown = true
        defaults.set(true, forKey: .appLockPromoShown)
    }

    // MARK: - App switcher privacy cover

    func showPrivacyCoverIfNeeded() {
        guard isEnabled else { return }
        // Don't cover the app while Face ID / passcode UI is up.
        guard !isAuthenticating else { return }
        showsPrivacyCover = true
        presentPrivacyWindowIfNeeded()
    }

    func hidePrivacyCover() {
        showsPrivacyCover = false
        dismissPrivacyWindow()
    }

    private func presentPrivacyWindowIfNeeded() {
        guard privacyWindow == nil else { return }

        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = windowScenes.first { scene in
            scene.activationState == .foregroundActive
                || scene.activationState == .foregroundInactive
        }
        guard let scene = activeScene ?? windowScenes.first else { return }

        let window = UIWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level.alert + 1
        window.backgroundColor = UIColor.black
        let host = UIHostingController(rootView: AppLockPrivacyCoverView())
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.makeKeyAndVisible()
        privacyWindow = window
    }

    private func dismissPrivacyWindow() {
        privacyWindow?.isHidden = true
        privacyWindow?.rootViewController = nil
        privacyWindow = nil
    }
}
