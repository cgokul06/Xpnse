//
//  FeedbackFlowView.swift
//  Xpnse
//

import SwiftUI

struct FeedbackFlowView: View {
    let opportunity: ReviewOpportunity

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .enjoyment
    @State private var feedbackText = ""
    @State private var isSubmitting = false
    @State private var submitError: String?

    private enum Step {
        case enjoyment
        case thankYou
        case feedbackForm
    }

    private var coordinator: UserEngagementCoordinator { .shared }
    private var engine: UserSatisfactionEngine { .shared }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .enjoyment:
                    enjoymentStep
                case .thankYou:
                    thankYouStep
                case .feedbackForm:
                    feedbackFormStep
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
                    .disabled(isSubmitting)
                    .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(sheetFill, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .xpnseEdgeSheetDismissDisabled(isSubmitting)
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
                    step = .thankYou
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
                    step = .feedbackForm
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
                AppStoreReviewRequester.requestReview()
                coordinator.reportAppStoreReviewOpened()
                dismiss()
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

    private var feedbackFormStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Help us improve SnapLedger")
                    .font(.system(size: 24, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .xpnseAdaptiveForeground()

                Text("What would make the app better for you?")
                    .font(.system(size: 15, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .xpnseAdaptiveForeground(muted: true)
            }
            .padding(.top, 8)

            TextEditor(text: $feedbackText)
                .frame(minHeight: 160)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(AdaptiveBrandSurface.fieldBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            AdaptiveBrandSurface.fieldBorder(for: colorScheme),
                            lineWidth: 1
                        )
                )
                .xpnseAdaptiveForeground()

            if let submitError {
                Text(submitError)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AdaptiveBrandSurface.fieldErrorBorder)
            }

            Spacer()

            Button {
                AppAnalytics.logButtonClick(
                    AppAnalytics.Button.reviewSendFeedback,
                    source: AppAnalytics.Screen.feedbackFlow
                )
                Task { await submitFeedback() }
            } label: {
                Text("Send Feedback")
                    .font(.system(size: 18, weight: .bold))
            }
            .buttonStyle(
                XpnsePrimaryButtonStyle.defaultButton(
                    isDisabled: Binding(
                        get: {
                            feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || isSubmitting
                        },
                        set: { _ in }
                    ),
                    isLoading: $isSubmitting
                )
            )
            .disabled(
                feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isSubmitting
            )
        }
    }

    // MARK: - Actions

    private func cancelFlow() {
        AppAnalytics.logButtonClick(
            AppAnalytics.Button.reviewDismiss,
            source: AppAnalytics.Screen.feedbackFlow
        )
        if step == .feedbackForm {
            AppAnalytics.logEvent(AppAnalytics.Event.reviewFeedbackCancelled)
        }
        coordinator.dismissCurrentEngagement(reportToEngine: true)
        dismiss()
    }

    private func submitFeedback() async {
        let message = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        isSubmitting = true
        submitError = nil
        do {
            if let transactions = try? await SwiftDataTransactionRepository.shared.fetchAll() {
                engine.reconcileLifetimeTransactionCount(transactions.count)
            }
            let recurringCount = (try? await SwiftDataRecurringRepository.shared.fetchAll())?.count ?? 0
            let snapshot = engine.snapshotForFeedback(recurringTransactionsCount: recurringCount)
            try await FeedbackUploadService.upload(
                FeedbackPayload(type: "suggestion", message: message, snapshot: snapshot)
            )
            coordinator.reportFeedbackSubmitted()
            dismiss()
        } catch {
            submitError = "Couldn't send feedback. Please try again."
            isSubmitting = false
        }
    }
}
