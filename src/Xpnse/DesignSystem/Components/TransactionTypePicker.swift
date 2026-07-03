//
//  TransactionTypePicker.swift
//  Xpnse
//

import SwiftUI

struct TransactionTypePicker: View {
    @Binding var selection: TransactionType
    var onSelectionChange: ((TransactionType) -> Void)?

    var body: some View {
        Menu {
            ForEach(TransactionType.pickerOrder, id: \.self) { type in
                Button {
                    selection = type
                    onSelectionChange?(type)
                } label: {
                    Label(type.displayName, systemImage: type.displayIcon)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selection.displayIcon)
                    .font(.system(size: 16, weight: .semibold))

                Text(selection.displayName)
                    .font(.system(size: 16, weight: .semibold))

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(selection.brandColor)
            .xpnseRoundedCorner()
        }
    }
}
