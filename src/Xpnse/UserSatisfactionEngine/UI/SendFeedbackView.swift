//
//  SendFeedbackView.swift
//  Xpnse
//

import SwiftUI

/// Full-screen feedback composer used from Settings and from the review suggestion path.
struct SendFeedbackView: View {
    /// When `true`, successful submit / cancel update review-engine outcomes.
    var marksReviewOutcome: Bool = false
    /// Show a leading close control (modal). Pushed Settings destinations use the back button instead.
    var showsCloseButton: Bool = false
    var onSuccess: (() -> Void)?
    var onCancel: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var feedbackText = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @FocusState private var isEditorFocused: Bool

    private var engine: UserSatisfactionEngine { .shared }
    private var coordinator: UserEngagementCoordinator { .shared }

    private var canSubmit: Bool {
        !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("feedback.form_title")
                            .font(.system(size: 28, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                            .xpnseAdaptiveForeground()

                        Text("feedback.form_subtitle")
                            .font(.system(size: 16, weight: .medium))
                            .fixedSize(horizontal: false, vertical: true)
                            .xpnseAdaptiveForeground(muted: true)
                    }

                    TextEditor(text: $feedbackText)
                        .focused($isEditorFocused)
                        .frame(minHeight: 220)
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }

            Button {
                AppAnalytics.logButtonClick(
                    AppAnalytics.Button.reviewSendFeedback,
                    source: AppAnalytics.Screen.sendFeedback
                )
                Task { await submitFeedback() }
            } label: {
                Text("feedback.send")
                    .font(.system(size: 18, weight: .bold))
            }
            .buttonStyle(
                XpnsePrimaryButtonStyle.defaultButton(
                    isDisabled: Binding(
                        get: { !canSubmit },
                        set: { _ in }
                    ),
                    isLoading: $isSubmitting
                )
            )
            .disabled(!canSubmit)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .bottomSpacingIfNoSafeArea(8)
            .background(AdaptiveBrandSurface.background(for: colorScheme))
        }
        .background(AdaptiveBrandSurface.background(for: colorScheme).ignoresSafeArea())
        .gradientNavigationBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        cancel()
                    } label: {
                        Image(systemName: "xmark")
                            .bold()
                            .padding(.all, 8)
                    }
                    .disabled(isSubmitting)
                    .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                }
            }

            ToolbarItem(placement: .principal) {
                Text("feedback.nav_title")
                    .font(.title3)
                    .fontWeight(.bold)
                    .xpnseAdaptiveForeground()
            }
        }
        .navigationBarBackButtonHidden(showsCloseButton)
        .interactiveDismissDisabled(isSubmitting)
        .onAppear {
            AppAnalytics.logScreen(AppAnalytics.Screen.sendFeedback)
            isEditorFocused = true
        }
    }

    private func cancel() {
        AppAnalytics.logButtonClick(
            AppAnalytics.Button.reviewDismiss,
            source: AppAnalytics.Screen.sendFeedback
        )
        AppAnalytics.logEvent(AppAnalytics.Event.reviewFeedbackCancelled)
        if marksReviewOutcome {
            coordinator.reportFeedbackCancelled()
        }
        if let onCancel {
            onCancel()
        } else {
            dismiss()
        }
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
            AppAnalytics.logEvent(AppAnalytics.Event.reviewFeedbackSubmitted)
            if marksReviewOutcome {
                coordinator.reportFeedbackSubmitted()
            }
            if let onSuccess {
                onSuccess()
            } else {
                dismiss()
            }
        } catch {
            submitError = L10n.tr("feedback.send_error")
            isSubmitting = false
        }
    }
}
