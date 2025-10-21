//
//  BottomActionBar.swift
//  Xpnse
//
//  Created by Gokul C on 05/07/25.
//

import SwiftUI

struct BottomActionBar: View {
    let action: () -> Void

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Button {
                    self.action()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(XpnseColorKey.white.color)
                        .frame(width: 100)
                }

                Spacer()

                Button {

                } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(XpnseColorKey.white.color)
                        .frame(width: 100)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
