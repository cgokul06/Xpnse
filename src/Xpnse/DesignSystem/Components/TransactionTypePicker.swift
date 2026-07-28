//
//  TransactionTypePicker.swift
//  Xpnse
//

import SwiftUI
import UIKit

struct TransactionTypePicker: View {
    @Binding var selection: TransactionType
    var isEnabled: Bool = true
    var onSelectionChange: ((TransactionType) -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TransactionType.pickerOrder, id: \.self) { type in
                segmentButton(for: type)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AdaptiveBrandSurface.segmentTrackBackground(for: colorScheme))
        )
        .opacity(isEnabled ? 1 : 0.55)
        .allowsHitTesting(isEnabled)
        .accessibilityElement(children: .contain)
    }

    private func segmentButton(for type: TransactionType) -> some View {
        let isSelected = selection == type

        return Button {
            guard isEnabled, selection != type else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = type
                onSelectionChange?(type)
            }
        } label: {
            Text(type.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(
                    isSelected
                        ? .white
                        : AdaptiveBrandSurface.mutedForeground(for: colorScheme)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(type.brandColor)
                                .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                        }
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
