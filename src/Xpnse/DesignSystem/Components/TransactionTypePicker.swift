//
//  TransactionTypePicker.swift
//  Xpnse
//

import SwiftUI
import UIKit

struct TransactionTypePicker: View {
    @Binding var selection: TransactionType
    var onSelectionChange: ((TransactionType) -> Void)?

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
                .fill(Color.white.opacity(0.12))
        )
    }

    private func segmentButton(for type: TransactionType) -> some View {
        let isSelected = selection == type

        return Button {
            guard selection != type else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = type
                onSelectionChange?(type)
            }
        } label: {
            Text(type.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
