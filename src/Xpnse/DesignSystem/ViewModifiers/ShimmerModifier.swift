//
//  ShimmerModifier.swift
//  Xpnse
//

import SwiftUI

enum ShimmerClipShape {
    case roundedRect(CGFloat)
    case capsule
}

/// Sweeping highlight for individual skeleton / ghost placeholder items.
struct ShimmerModifier: ViewModifier {
    var clipShape: ShimmerClipShape = .roundedRect(4)

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        clippedOverlay(content)
            .onAppear {
                guard !reduceMotion else { return }
                phase = 0
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }

    @ViewBuilder
    private func clippedOverlay(_ content: Content) -> some View {
        switch clipShape {
        case .roundedRect(let radius):
            content
                .overlay { shimmerBand }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .capsule:
            content
                .overlay { shimmerBand }
                .clipShape(Capsule(style: .continuous))
        }
    }

    private var shimmerBand: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let bandWidth = max(width * 0.55, 12)

            LinearGradient(
                colors: [
                    Color.clear,
                    highlight.opacity(colorScheme == .dark ? 0.12 : 0.40),
                    highlight.opacity(colorScheme == .dark ? 0.32 : 0.75),
                    highlight.opacity(colorScheme == .dark ? 0.12 : 0.40),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: bandWidth)
            .offset(x: -bandWidth + phase * (width + bandWidth))
            .blendMode(colorScheme == .dark ? .plusLighter : .softLight)
        }
        .allowsHitTesting(false)
    }

    private var highlight: Color { .white }
}

extension View {
    /// Adds a moving light band clipped to this placeholder item.
    func shimmering(_ clipShape: ShimmerClipShape = .roundedRect(4)) -> some View {
        modifier(ShimmerModifier(clipShape: clipShape))
    }
}
