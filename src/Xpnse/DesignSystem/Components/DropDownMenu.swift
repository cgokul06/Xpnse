//
//  DropDownMenu.swift
//  Xpnse
//
//  Created by Gokul C on 26/10/25.
//

import SwiftUI

struct DropDownMenu: View {
    let options: [TransactionCategory]

    var menuWdith: CGFloat = 250
    private let buttonHeight: CGFloat = 40
    var maxItemDisplayed: Int = 3

    @Binding var selectedCategory: TransactionCategory
    @State private var showDropdown: Bool = false
    @State private var scrollPosition: TransactionCategory?

    var body: some  View {
        VStack {
            VStack(spacing: 0) {
                // selected item
                Button(action: {
                    withAnimation(.easeInOut) {
                        showDropdown.toggle()
                    }
                }, label: {
                    HStack(spacing: nil) {
                        HStack(spacing: 8) {
                            Image(systemName: selectedCategory.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 20, height: 20)

                            Text(selectedCategory.displayName)
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

                // selection menu
                if (showDropdown) {
                    let scrollViewHeight: CGFloat  = options.count > maxItemDisplayed ? (buttonHeight*CGFloat(maxItemDisplayed)) : (buttonHeight*CGFloat(options.count))
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(options, id: \.self) { option in
                                Button(action: {
                                    withAnimation(.easeInOut) {                                        selectedCategory = option
                                        showDropdown.toggle()
                                    }
                                }, label: {
                                    HStack {
                                        HStack(spacing: 8) {
                                            Image(systemName: option.icon)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 18, height: 18)

                                            Text(option.displayName)
                                                .font(.system(size: 18, weight: .semibold))
                                        }

                                        Spacer()

                                        if (option == selectedCategory) {
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
                    .scrollDisabled(options.count <=  3)
                    .frame(height: scrollViewHeight)
                    .onAppear {
                        scrollPosition = selectedCategory
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
