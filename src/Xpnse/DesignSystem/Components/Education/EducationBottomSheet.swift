//
//  EducationBottomSheet.swift
//  Xpnse
//

import SwiftUI

/// Reusable education sheet **content**. Presentation (`.sheet`, `XpnseEdgeAttachedSheet`, etc.) is owned by the parent.
struct EducationBottomSheet<Illustration: View, CustomContent: View>: View {
    let model: EducationSheetModel
    let onPrimary: () -> Void
    var onSecondary: (() -> Void)?
    var onDismiss: (() -> Void)?

    @ViewBuilder var illustration: () -> Illustration
    @ViewBuilder var customContent: () -> CustomContent

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        model: EducationSheetModel,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder illustration: @escaping () -> Illustration,
        @ViewBuilder customContent: @escaping () -> CustomContent
    ) {
        self.model = model
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        self.onDismiss = onDismiss
        self.illustration = illustration
        self.customContent = customContent
    }

    private var showsIllustrationSlot: Bool {
        Illustration.self != EmptyView.self
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            stack(scrollingText: false)
            stack(scrollingText: true)
        }
        .onDisappear {
            onDismiss?()
        }
    }

    @ViewBuilder
    private func stack(scrollingText: Bool) -> some View {
        VStack(spacing: 14) {
            heroSection

            if scrollingText {
                ScrollView(.vertical, showsIndicators: false) {
                    textAndCustom
                }
            } else {
                textAndCustom
            }

            buttonSection
                .padding(.top, 16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: scrollingText ? CGFloat.infinity : nil)
    }

    private var textAndCustom: some View {
        VStack(spacing: 14) {
            textSection
            customContent()
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        if showsIllustrationSlot {
            illustration()
                .frame(maxWidth: .infinity)
        } else if let icon = model.icon {
            EducationSheetIconView(icon: icon, colorScheme: colorScheme)
        }
    }

    private var textSection: some View {
        VStack(spacing: 10) {
            Text(model.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .xpnseAdaptiveForeground()
                .accessibilityAddTraits(.isHeader)

            Text(model.description)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .xpnseAdaptiveForeground(muted: true)
        }
    }

    private var buttonSection: some View {
        VStack(spacing: 12) {
            EducationSheetButtonRow(
                button: model.primaryButton,
                style: .primary,
                reduceMotion: reduceMotion,
                action: onPrimary
            )

            if let secondary = model.secondaryButton, let onSecondary {
                EducationSheetButtonRow(
                    button: secondary,
                    style: .secondary,
                    reduceMotion: reduceMotion,
                    action: onSecondary
                )
            }
        }
    }
}

// MARK: - Convenience inits

extension EducationBottomSheet where Illustration == EmptyView, CustomContent == EmptyView {
    init(
        model: EducationSheetModel,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.init(
            model: model,
            onPrimary: onPrimary,
            onSecondary: onSecondary,
            onDismiss: onDismiss,
            illustration: { EmptyView() },
            customContent: { EmptyView() }
        )
    }
}

extension EducationBottomSheet where CustomContent == EmptyView {
    init(
        model: EducationSheetModel,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder illustration: @escaping () -> Illustration
    ) {
        self.init(
            model: model,
            onPrimary: onPrimary,
            onSecondary: onSecondary,
            onDismiss: onDismiss,
            illustration: illustration,
            customContent: { EmptyView() }
        )
    }
}

extension EducationBottomSheet where Illustration == EmptyView {
    init(
        model: EducationSheetModel,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder customContent: @escaping () -> CustomContent
    ) {
        self.init(
            model: model,
            onPrimary: onPrimary,
            onSecondary: onSecondary,
            onDismiss: onDismiss,
            illustration: { EmptyView() },
            customContent: customContent
        )
    }
}

// MARK: - Subviews

private struct EducationSheetIconView: View {
    let icon: EducationSheetIcon
    let colorScheme: ColorScheme

    var body: some View {
        switch icon {
        case .sfSymbol(let name):
            Image(systemName: name)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                .accessibilityHidden(true)
        }
    }
}

private struct EducationSheetButtonRow: View {
    enum Style {
        case primary
        case secondary
    }

    let button: EducationSheetButtonModel
    let style: Style
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Group {
            switch style {
            case .primary:
                Button(action: action) {
                    buttonLabel
                }
                .buttonStyle(
                    XpnsePrimaryButtonStyle.defaultButton(
                        isDisabled: .constant(button.isDisabled),
                        isLoading: .constant(button.isLoading)
                    )
                )
            case .secondary:
                Button(action: action) {
                    buttonLabel
                }
                .buttonStyle(
                    XpnseSecondaryButtonStyle.defaultButton(
                        isDisabled: .constant(button.isDisabled),
                        isLoading: .constant(button.isLoading)
                    )
                )
            }
        }
        .accessibilityLabel(button.accessibilityLabel ?? button.title)
        .animation(reduceMotion ? nil : .default, value: button.isLoading)
    }

    private var buttonLabel: some View {
        HStack(spacing: 8) {
            if button.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.85)
            }

            Text(button.title)
                .font(.system(size: 18, weight: style == .primary ? .bold : .semibold))
                .accessibilityShowsLargeContentViewer()
        }
    }
}
