//
//  DropDownMenu.swift
//  Xpnse
//
//  Created by Gokul C on 26/10/25.
//

import SwiftUI

struct DropDownMenu: View {
    let options: [CategoryDefinition]

    var menuWdith: CGFloat = 250
    private let buttonHeight: CGFloat = 40
    var maxItemDisplayed: Int = 3

    @Binding var selectedCategoryId: String
    @Binding var showDropdown: Bool
    @State private var scrollPosition: String?

    private var selectedCategory: CategoryDefinition {
        options.first(where: { $0.id == selectedCategoryId })
            ?? CategoryStore.shared.resolve(id: selectedCategoryId)
    }

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut) {
                        self.hideKeyboard()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showDropdown.toggle()
                        }
                    }
                }, label: {
                    HStack(spacing: nil) {
                        HStack(spacing: 8) {
                            CategoryIconBadge(
                                symbolName: selectedCategory.symbolName,
                                colorHex: selectedCategory.colorHex,
                                size: 28
                            )

                            Text(selectedCategory.name)
                                .font(.system(size: 20, weight: .bold))
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees((showDropdown ? -180 : 0)))
                    }
                })
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .frame(width: menuWdith, alignment: .leading)

                if showDropdown {
                    let scrollViewHeight: CGFloat = options.count > maxItemDisplayed
                        ? (buttonHeight * CGFloat(maxItemDisplayed))
                        : (buttonHeight * CGFloat(options.count))
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(options) { option in
                                Button(action: {
                                    withAnimation(.easeInOut) {
                                        selectedCategoryId = option.id
                                        showDropdown.toggle()
                                    }
                                }, label: {
                                    HStack {
                                        HStack(spacing: 8) {
                                            CategoryIconBadge(
                                                symbolName: option.symbolName,
                                                colorHex: option.colorHex,
                                                size: 24
                                            )

                                            Text(option.name)
                                                .font(.system(size: 18, weight: .semibold))
                                        }

                                        Spacer()

                                        if option.id == selectedCategoryId {
                                            Image(systemName: "checkmark.circle.fill")
                                        }
                                    }
                                })
                                .padding(.horizontal, 20)
                                .frame(width: menuWdith, height: buttonHeight, alignment: .leading)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollPosition(id: $scrollPosition)
                    .scrollDisabled(options.count <= 3)
                    .frame(height: scrollViewHeight)
                    .onAppear {
                        scrollPosition = selectedCategoryId
                    }
                }
            }
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        showDropdown ? Color(red: 0.6, green: 0.3, blue: 0.9) : XpnseColorKey.whiteWithAlphaFifteen.color
                    )
            )
            .xpnseRoundedCorner(strokeConfig: StrokeConfig(color: .whiteWithAlphaThirty, lineWidth: 2))
        }
        .frame(width: menuWdith, height: buttonHeight, alignment: .top)
        .zIndex(100)
    }
}
