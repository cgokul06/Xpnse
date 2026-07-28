//
//  TransactionItemView.swift
//  Xpnse
//
//  Created by Gokul C on 22/10/25.
//

import SwiftUI

enum TransactionItemSubtitle {
    case date
    case category
}

struct TransactionItemView: View {
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @Environment(\.colorScheme) private var colorScheme
    @State private var isTapped = false
    var transaction: Transaction
    var subtitle: TransactionItemSubtitle = .date
    /// When false (category-grouped list), omit the leading emoji and accent band.
    var showsLeadingCategoryIcon: Bool = true

    private static let emojiSize: CGFloat = 30
    private static let accentSideInset: CGFloat = 10
    private static let contentLeadingGap: CGFloat = 12

    private var categoryColor: Color {
        Color(hex: transaction.categoryColorHex)
    }

    private var accentBandWidth: CGFloat {
        Self.accentSideInset + Self.emojiSize + Self.accentSideInset
    }

    var body: some View {
        HStack(spacing: 0) {
            if showsLeadingCategoryIcon {
                categoryAccentBand
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.title)
                        .font(.system(size: 16, weight: .semibold))
                        .xpnseAdaptiveForeground()
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        switch subtitle {
                        case .date:
                            Text(transaction.formattedDate)
                                .font(.system(size: 12, weight: .medium))
                                .xpnseAdaptiveForeground(muted: true)
                        case .category:
                            Text(transaction.categoryDisplayName)
                                .font(.system(size: 12, weight: .medium))
                                .xpnseAdaptiveForeground(muted: true)
                        }

                        if transaction.isRecurringGenerated {
                            Text("Recurring")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.85))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer(minLength: 8)

                Text(transaction.currency.symbol + " " + transaction.formattedAmount)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .xpnseAdaptiveForeground()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.leading, showsLeadingCategoryIcon ? Self.contentLeadingGap : 12)
            .padding(.trailing, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .xpnseOutlinedPanel(borderColor: showsLeadingCategoryIcon ? categoryColor : nil)
        .scaleEffect(isTapped ? 0.98 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isTapped)
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                isTapped = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    isTapped = false
                }
                self.homeCoordinator.push(.editTransaction(transaction: transaction))
            }
        }
    }

    private var categoryAccentBand: some View {
        ZStack {
            categoryColor

            CategoryIconBadge(
                symbolName: transaction.categorySymbolName,
                colorHex: transaction.categoryColorHex,
                size: Self.emojiSize,
                showsColorBackground: false
            )
        }
        .frame(width: accentBandWidth)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(seamHighlight)
                .frame(width: 1)
        }
    }

    private var seamHighlight: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.white.opacity(0.45)
    }
}
