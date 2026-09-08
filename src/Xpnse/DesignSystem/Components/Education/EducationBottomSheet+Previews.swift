//
//  EducationBottomSheet+Previews.swift
//  Xpnse
//

import SwiftUI

// MARK: - Preview helpers

private enum EducationPreviewData {
    static let incomeSetup = EducationSheetModel(
        id: "preview-income",
        icon: .sfSymbol("plus.circle.fill"),
        title: "Track Your Income",
        description: "Add your salary or other income sources to get a complete picture of your finances.",
        primaryButton: EducationSheetButtonModel(id: "primary", title: "Add Income"),
        secondaryButton: EducationSheetButtonModel(id: "secondary", title: "Maybe Later")
    )

    static let reminder = EducationSheetModel(
        id: "preview-reminder",
        icon: .sfSymbol("bell.badge.fill"),
        title: "Stay on Top of Bills",
        description: "Enable reminders so you never miss an upcoming recurring transaction.",
        primaryButton: EducationSheetButtonModel(id: "primary", title: "Enable Reminder"),
        secondaryButton: EducationSheetButtonModel(id: "secondary", title: "Not Now")
    )

    static let widget = EducationSheetModel(
        id: "preview-widget",
        title: "Balance at a Glance",
        description: "Add the Balance widget to your Home Screen for a quick snapshot of your current period.",
        primaryButton: EducationSheetButtonModel(id: "primary", title: "Add Widget"),
        secondaryButton: EducationSheetButtonModel(id: "secondary", title: "Maybe Later")
    )

    static let singleButton = EducationSheetModel(
        id: "preview-single",
        icon: .sfSymbol("sparkles"),
        title: "You're All Set",
        description: "Your categories are ready. Start tracking expenses whenever you're ready.",
        primaryButton: EducationSheetButtonModel(id: "primary", title: "Got It")
    )

    static let loading = EducationSheetModel(
        id: "preview-loading",
        icon: .sfSymbol("bell.fill"),
        title: "Enable Notifications",
        description: "We'll remind you before recurring transactions are due.",
        primaryButton: EducationSheetButtonModel(
            id: "primary",
            title: "Enable Notifications",
            isLoading: true
        ),
        secondaryButton: EducationSheetButtonModel(id: "secondary", title: "Not Now")
    )

    static let longDescription = EducationSheetModel(
        id: "preview-long",
        icon: .sfSymbol("doc.text.viewfinder"),
        title: "Scan Receipts Instantly",
        description: """
        Point your camera at any receipt and SnapLedger extracts the amount, merchant, date, and category automatically.

        Your data stays on your device. Nothing is uploaded to the cloud unless you choose to sync.

        You can always edit the details before saving, and scan from the Add Transaction screen at any time.
        """,
        primaryButton: EducationSheetButtonModel(id: "primary", title: "Try Scanner"),
        secondaryButton: EducationSheetButtonModel(id: "secondary", title: "Maybe Later")
    )
}

private struct PreviewSheetContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            AdaptiveBrandSurface.background(for: colorScheme)
                .ignoresSafeArea()
            content()
                .frame(maxWidth: 390)
        }
    }
}

private struct WidgetIllustrationPlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AdaptiveBrandSurface.elevatedSurfaceBackground(for: colorScheme))
            .frame(height: 120)
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 28, weight: .semibold))
                    Text("Widget Preview")
                        .font(.caption.weight(.medium))
                }
                .xpnseAdaptiveForeground(muted: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Widget preview placeholder")
    }
}

// MARK: - Content previews

#Preview("Income Setup") {
    PreviewSheetContainer {
        EducationBottomSheet(
            model: EducationPreviewData.incomeSetup,
            onPrimary: {},
            onSecondary: {}
        )
    }
}

#Preview("Reminder") {
    PreviewSheetContainer {
        EducationBottomSheet(
            model: EducationPreviewData.reminder,
            onPrimary: {},
            onSecondary: {}
        )
    }
}

#Preview("Widget") {
    PreviewSheetContainer {
        EducationBottomSheet(
            model: EducationPreviewData.widget,
            onPrimary: {},
            onSecondary: {},
            illustration: {
                WidgetIllustrationPlaceholder()
            }
        )
    }
}

#Preview("Single Button") {
    PreviewSheetContainer {
        EducationBottomSheet(
            model: EducationPreviewData.singleButton,
            onPrimary: {}
        )
    }
}

#Preview("Loading") {
    PreviewSheetContainer {
        EducationBottomSheet(
            model: EducationPreviewData.loading,
            onPrimary: {},
            onSecondary: {}
        )
    }
}

#Preview("Long Description") {
    PreviewSheetContainer {
        EducationBottomSheet(
            model: EducationPreviewData.longDescription,
            onPrimary: {},
            onSecondary: {}
        )
    }
}

// MARK: - Edge-attached shell previews

#Preview("Income — Edge Sheet") {
    XpnseEdgeAttachedSheet(sizing: .hug()) {
        EducationBottomSheet(
            model: EducationPreviewData.incomeSetup,
            onPrimary: {},
            onSecondary: {}
        )
    }
}

#Preview("Widget — Edge Sheet Dark") {
    XpnseEdgeAttachedSheet(sizing: .hug()) {
        EducationBottomSheet(
            model: EducationPreviewData.widget,
            onPrimary: {},
            onSecondary: {},
            illustration: {
                WidgetIllustrationPlaceholder()
            }
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Long Description — Edge Sheet") {
    XpnseEdgeAttachedSheet(sizing: .hug()) {
        EducationBottomSheet(
            model: EducationPreviewData.longDescription,
            onPrimary: {},
            onSecondary: {}
        )
    }
}

#Preview("Long Description — Large Type") {
    PreviewSheetContainer {
        EducationBottomSheet(
            model: EducationPreviewData.longDescription,
            onPrimary: {},
            onSecondary: {}
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
