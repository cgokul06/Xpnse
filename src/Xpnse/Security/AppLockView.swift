//
//  AppLockView.swift
//  Xpnse
//

import SwiftUI

struct AppLockView: View {
    @State private var appLock = AppLockController.shared
    @State private var didAttemptAutoUnlock = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0x03 / 255, green: 0x1B / 255, blue: 0x2E / 255),
                    Color(red: 0x0A / 255, green: 0x34 / 255, blue: 0x52 / 255)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("SplashIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text("SnapLedger")
                    .font(.custom("ArialRoundedMTBold", size: 28))
                    .foregroundStyle(.white)

                Text("app_lock.locked_message")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    Task {
                        _ = await appLock.unlockWithBiometricsOrPasscode()
                    }
                } label: {
                    Label("app_lock.unlock", systemImage: "faceid")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(appLock.isAuthenticating)
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
        }
        .task {
            guard !didAttemptAutoUnlock else { return }
            didAttemptAutoUnlock = true
            _ = await appLock.unlockWithBiometricsOrPasscode()
        }
    }
}

/// Opaque branded cover used for app-switcher snapshots when lock is enabled.
struct AppLockPrivacyCoverView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0x03 / 255, green: 0x1B / 255, blue: 0x2E / 255),
                    Color(red: 0x0A / 255, green: 0x34 / 255, blue: 0x52 / 255)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("SplashIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Text("SnapLedger")
                    .font(.custom("ArialRoundedMTBold", size: 26))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct AppLockPromoView: View {
    var onEnable: () -> Void
    var onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismissXpnseEdgeSheet) private var dismissEdgeSheet

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 4)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("app_lock.promo_title")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .xpnseAdaptiveForeground()

                Text("app_lock.promo_subtitle")
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .xpnseAdaptiveForeground(muted: true)
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button {
                    AppAnalytics.logButtonClick(
                        AppAnalytics.Button.appLockPromoEnable,
                        source: AppAnalytics.Screen.appLockPromo
                    )
                    AppAnalytics.logEvent(AppAnalytics.Event.appLockPromoEnable)
                    onEnable()
                    dismissEdgeSheet()
                } label: {
                    Text("app_lock.promo_enable")
                        .font(.system(size: 18, weight: .bold))
                }
                .buttonStyle(
                    XpnsePrimaryButtonStyle.defaultButton(
                        isDisabled: .constant(false),
                        isLoading: .constant(false)
                    )
                )

                Button {
                    AppAnalytics.logButtonClick(
                        AppAnalytics.Button.appLockPromoNotNow,
                        source: AppAnalytics.Screen.appLockPromo
                    )
                    AppAnalytics.logEvent(AppAnalytics.Event.appLockPromoDismiss)
                    onDismiss()
                    dismissEdgeSheet()
                } label: {
                    Text("app_lock.promo_not_now")
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(
                    XpnseSecondaryButtonStyle.defaultButton(
                        isDisabled: .constant(false),
                        isLoading: .constant(false)
                    )
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .onAppear {
            AppAnalytics.logScreen(AppAnalytics.Screen.appLockPromo)
            AppAnalytics.logEvent(AppAnalytics.Event.appLockPromoPresented)
            AppLockController.shared.markPromoShown()
        }
    }
}
