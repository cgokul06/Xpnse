//
//  XpnseSheetSurface.swift
//  Xpnse
//

import SwiftUI

/// Edge-attached bottom sheet chrome for iOS 26+.
///
/// System `.sheet` + partial detents float inset from the screen edges (Liquid Glass).
/// This presents a classic full-width card that is flush with the bottom edge.
struct XpnseEdgeAttachedSheet<Content: View>: View {
    var heightFraction: CGFloat = 0.5
    var allowsTapDismiss: Bool = true
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var isVisible = false
    @State private var dragOffset: CGFloat = 0
    @State private var dismissDisabledFromContent = false

    private var fill: Color {
        AdaptiveBrandSurface.sheetSurfaceBackground(for: colorScheme)
    }

    private var canDismissInteractively: Bool {
        allowsTapDismiss && !dismissDisabledFromContent
    }

    /// Background stays flush; content sits above the home indicator (or 8pt if none).
    private var contentBottomInset: CGFloat {
        let safeBottom = DeviceSafeArea.bottom
        return safeBottom > 0 ? safeBottom : 8
    }

    var body: some View {
        GeometryReader { geo in
            let sheetHeight = max(280, geo.size.height * heightFraction)

            ZStack(alignment: .bottom) {
                Color.black
                    .opacity(isVisible ? 0.4 : 0)
                    .ignoresSafeArea()
                    .onTapGesture {
                        guard canDismissInteractively else { return }
                        dismissSheet()
                    }

                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.primary.opacity(0.18))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .gesture(dragGesture(sheetHeight: sheetHeight))
                        .accessibilityHidden(true)

                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    // Keep buttons above the home indicator; chrome fill still bleeds flush below.
                    Color.clear
                        .frame(height: contentBottomInset)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
                .frame(height: sheetHeight, alignment: .top)
                .background {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 28,
                        style: .continuous
                    )
                    .fill(fill)
                    .ignoresSafeArea(edges: .bottom)
                }
                .offset(y: isVisible ? dragOffset : sheetHeight + 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
        .presentationBackground(.clear)
        .onPreferenceChange(XpnseEdgeSheetDismissDisabledKey.self) { disabled in
            dismissDisabledFromContent = disabled
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                isVisible = true
            }
        }
    }

    private func dragGesture(sheetHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard canDismissInteractively else { return }
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                guard canDismissInteractively else {
                    dragOffset = 0
                    return
                }
                let shouldDismiss =
                    value.translation.height > sheetHeight * 0.25
                    || value.predictedEndTranslation.height > sheetHeight * 0.45
                if shouldDismiss {
                    dismissSheet()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func dismissSheet() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.92)) {
            isVisible = false
            dragOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            dismiss()
        }
    }
}

private struct XpnseEdgeSheetDismissDisabledKey: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    /// Opt out of tap / drag dismiss while a sheet is in a critical state (e.g. submitting).
    func xpnseEdgeSheetDismissDisabled(_ disabled: Bool) -> some View {
        preference(key: XpnseEdgeSheetDismissDisabledKey.self, value: disabled)
    }
}
