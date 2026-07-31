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
            ZStack {
                PrimaryGradient()
                    .ignoresSafeArea()

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
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelFlow()
                    }
                    .disabled(isSubmitting)
                    .xpnseAdaptiveForeground()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    // MARK: - Steps

    private var enjoymentStep: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            Text("❤️")
                .font(.system(size: 48))

            VStack(spacing: 10) {
                Text("Enjoying SnapLedger?")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .xpnseAdaptiveForeground()

                Text(opportunity.title)
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                    .xpnseAdaptiveForeground(muted: true)

                Text("Your feedback helps us build a better app for everyone.")
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .xpnseAdaptiveForeground(muted: true)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
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
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            Text("✨")
                .font(.system(size: 48))

            VStack(spacing: 10) {
                Text("Thank you!")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .xpnseAdaptiveForeground()

                Text("Would you mind leaving us a quick App Store review?")
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                    .xpnseAdaptiveForeground(muted: true)

                Text("Your support helps more people discover SnapLedger.")
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .xpnseAdaptiveForeground(muted: true)
            }

            Spacer()

            Button {
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
                    .xpnseAdaptiveForeground()

                Text("What would make the app better for you?")
                    .font(.system(size: 15, weight: .medium))
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
            let snapshot = engine.snapshotForFeedback()
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
