//
//  XpnseSheetSurface.swift
//  Xpnse
//

import SwiftUI

/// How an edge-attached sheet chooses its card height.
enum XpnseEdgeSheetSizing: Equatable, Sendable {
    /// Fixed fraction of the container height. Minimum 280pt.
    case fraction(CGFloat)
    /// Height follows content, capped at `maxFraction` of the container.
    case hugContent(maxFraction: CGFloat)

    static func hug(maxFraction: CGFloat = 0.85) -> XpnseEdgeSheetSizing {
        .hugContent(maxFraction: maxFraction)
    }
}

/// Edge-attached bottom sheet chrome for iOS 26+.
///
/// System `.sheet` + partial detents float inset from the screen edges (Liquid Glass).
/// This presents a classic full-width card that is flush with the bottom edge.
struct XpnseEdgeAttachedSheet<Content: View>: View {
    var sizing: XpnseEdgeSheetSizing = .fraction(0.5)
    var allowsTapDismiss: Bool = true
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var isVisible = false
    @State private var dragOffset: CGFloat = 0
    @State private var dismissDisabledFromContent = false
    @State private var renderedCardHeight: CGFloat = 280

    init(
        sizing: XpnseEdgeSheetSizing = .fraction(0.5),
        allowsTapDismiss: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sizing = sizing
        self.allowsTapDismiss = allowsTapDismiss
        self.content = content
    }

    init(
        heightFraction: CGFloat,
        allowsTapDismiss: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            sizing: .fraction(heightFraction),
            allowsTapDismiss: allowsTapDismiss,
            content: content
        )
    }

    private var fill: Color {
        AdaptiveBrandSurface.sheetSurfaceBackground(for: colorScheme)
    }

    private var canDismissInteractively: Bool {
        allowsTapDismiss && !dismissDisabledFromContent
    }

    /// Grabber capsule + vertical padding.
    private var grabberChromeHeight: CGFloat { 21 }

    /// Background stays flush; content sits above the home indicator (or 8pt if none).
    private var contentBottomInset: CGFloat {
        let safeBottom = DeviceSafeArea.bottom
        return safeBottom > 0 ? safeBottom : 8
    }

    var body: some View {
        GeometryReader { geo in
            let sheetHeight = resolvedSheetHeight(containerHeight: geo.size.height)
            let maxContentHeight = maxContentHeight(containerHeight: geo.size.height)
            let dragHeight = dragSheetHeight(resolvedHeight: sheetHeight)

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
                        .gesture(dragGesture(sheetHeight: dragHeight))
                        .accessibilityHidden(true)

                    content()
                        .frame(maxWidth: .infinity, alignment: .top)
                        .frame(maxHeight: maxContentHeight, alignment: .top)

                    // Keep buttons above the home indicator; chrome fill still bleeds flush below.
                    Color.clear
                        .frame(height: contentBottomInset)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
                .modifier(XpnseEdgeSheetHeightModifier(sizing: sizing, sheetHeight: sheetHeight))
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
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    renderedCardHeight = newHeight
                }
                .offset(y: isVisible ? dragOffset : dragHeight + 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
        .presentationBackground(.clear)
        .environment(\.dismissXpnseEdgeSheet) {
            dismissSheet()
        }
        .onPreferenceChange(XpnseEdgeSheetDismissDisabledKey.self) { disabled in
            dismissDisabledFromContent = disabled
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                isVisible = true
            }
        }
    }

    private func resolvedSheetHeight(containerHeight: CGFloat) -> CGFloat {
        switch sizing {
        case .fraction(let fraction):
            return max(280, containerHeight * fraction)
        case .hugContent:
            return renderedCardHeight
        }
    }

    private func maxContentHeight(containerHeight: CGFloat) -> CGFloat {
        let chrome = grabberChromeHeight + contentBottomInset
        switch sizing {
        case .fraction:
            return max(0, resolvedSheetHeight(containerHeight: containerHeight) - chrome)
        case .hugContent(let maxFraction):
            return max(0, containerHeight * maxFraction - chrome)
        }
    }

    private func dragSheetHeight(resolvedHeight: CGFloat) -> CGFloat {
        switch sizing {
        case .fraction:
            return resolvedHeight
        case .hugContent:
            return max(renderedCardHeight, 1)
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

private struct XpnseEdgeSheetHeightModifier: ViewModifier {
    let sizing: XpnseEdgeSheetSizing
    let sheetHeight: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        switch sizing {
        case .fraction:
            content.frame(height: sheetHeight, alignment: .top)
        case .hugContent:
            content.fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct XpnseEdgeSheetDismissDisabledKey: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct XpnseEdgeSheetDismissKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Animates the edge-attached sheet away, then dismisses the cover.
    var dismissXpnseEdgeSheet: () -> Void {
        get { self[XpnseEdgeSheetDismissKey.self] }
        set { self[XpnseEdgeSheetDismissKey.self] = newValue }
    }
}

extension View {
    /// Opt out of tap / drag dismiss while a sheet is in a critical state (e.g. submitting).
    func xpnseEdgeSheetDismissDisabled(_ disabled: Bool) -> some View {
        preference(key: XpnseEdgeSheetDismissDisabledKey.self, value: disabled)
    }
}
