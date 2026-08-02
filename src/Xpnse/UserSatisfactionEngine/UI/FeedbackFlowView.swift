//
//  FeedbackFlowView.swift
//  Xpnse
//

import SwiftUI

struct FeedbackFlowView: View {
    let opportunity: ReviewOpportunity
    /// Called before the sheet dismisses so the host can run a follow-up after animation.
    var onRequestSendFeedback: () -> Void = {}
    var onRequestAppStoreReview: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismissXpnseEdgeSheet) private var dismissEdgeSheet

    @State private var step: Step = .enjoyment

    private enum Step {
        case enjoyment
        case thankYou
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .enjoyment:
                    enjoymentStep
                case .thankYou:
                    thankYouStep
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        cancelFlow()
                    } label: {
                        Image(systemName: "xmark")
                            .bold()
                            .padding(.all, 8)
                    }
                    .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(sheetFill, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            AppAnalytics.logScreen(AppAnalytics.Screen.feedbackFlow)
        }
    }

    private var sheetFill: Color {
        AdaptiveBrandSurface.sheetSurfaceBackground(for: colorScheme)
    }

    // MARK: - Steps

    private var enjoymentStep: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 4)

            Text("❤️")
                .font(.system(size: 48))

            VStack(spacing: 10) {
                Text("Enjoying SnapLedger?")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .xpnseAdaptiveForeground()

                VStack(spacing: 2) {
                    Text("Your feedback helps us build")
                    Text("a better app for everyone.")
                }
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .xpnseAdaptiveForeground(muted: true)
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button {
                    AppAnalytics.logButtonClick(
                        AppAnalytics.Button.reviewLovingIt,
                        source: AppAnalytics.Screen.feedbackFlow
                    )
                    AppAnalytics.logEvent(AppAnalytics.Event.reviewPositiveSelected)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        step = .thankYou
                    }
                } label: {
                    Text("😊  Loving it")
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
                        AppAnalytics.Button.reviewHaveSuggestion,
                        source: AppAnalytics.Screen.feedbackFlow
                    )
                    AppAnalytics.logEvent(AppAnalytics.Event.reviewNegativeSelected)
                    onRequestSendFeedback()
                    dismissEdgeSheet()
                } label: {
                    Text("💡  I Have a Suggestion")
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
    }

    private var thankYouStep: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 4)

            Text("✨")
                .font(.system(size: 48))

            VStack(spacing: 10) {
                Text("Thank you!")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .xpnseAdaptiveForeground()

                VStack(spacing: 2) {
                    Text("Would you mind leaving us")
                    Text("a quick App Store review?")
                }
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .xpnseAdaptiveForeground(muted: true)

                VStack(spacing: 2) {
                    Text("Your support helps more people")
                    Text("discover SnapLedger.")
                }
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .xpnseAdaptiveForeground(muted: true)
            }

            Spacer(minLength: 0)

            Button {
                AppAnalytics.logButtonClick(
                    AppAnalytics.Button.reviewLeaveReview,
                    source: AppAnalytics.Screen.feedbackFlow
                )
                onRequestAppStoreReview()
                dismissEdgeSheet()
            } label: {
                Text("Leave a Review")
                    .font(.system(size: 18, weight: .bold))
            }
            .buttonStyle(
                XpnsePrimaryButtonStyle.defaultButton(
                    isDisabled: .constant(false),
                    isLoading: .constant(false)
                )
            )
        }
    }

    // MARK: - Actions

    private func cancelFlow() {
        AppAnalytics.logButtonClick(
            AppAnalytics.Button.reviewDismiss,
            source: AppAnalytics.Screen.feedbackFlow
        )
        dismissEdgeSheet()
    }
}
