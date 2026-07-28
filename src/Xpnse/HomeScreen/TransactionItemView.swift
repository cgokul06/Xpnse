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
    @State private var isTapped = false
    var transaction: Transaction
    var subtitle: TransactionItemSubtitle = .date
    /// When false (category-grouped list), omit the leading emoji and use the default grey border.
    var showsLeadingCategoryIcon: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            if showsLeadingCategoryIcon {
                CategoryIconBadge(
                    symbolName: transaction.categorySymbolName,
                    colorHex: transaction.categoryColorHex,
                    size: 32,
                    showsColorBackground: false
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(transaction.title)
                    .font(.system(size: 16, weight: .medium))
                    .xpnseAdaptiveForeground()

                HStack(spacing: 12) {
                    switch subtitle {
                    case .date:
                        Text(transaction.formattedDate)
                            .font(.system(size: 12, weight: .light))
                            .xpnseAdaptiveForeground(muted: true)
                    case .category:
                        Text(transaction.categoryDisplayName)
                            .font(.system(size: 12, weight: .light))
                            .xpnseAdaptiveForeground(muted: true)
                    }

                    if transaction.isRecurringGenerated {
                        Text("Recurring")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer(minLength: 0)

            Text(transaction.currency.symbol + " " + transaction.formattedAmount)
                .font(.system(size: 20, weight: .medium))
                .xpnseAdaptiveForeground()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .xpnseOutlinedPanel(borderColor: rowBorderColor)
        .scaleEffect(isTapped ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTapped)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isTapped = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isTapped = false
                }
                self.homeCoordinator.push(.editTransaction(transaction: transaction))
            }
        }
    }

    private var rowBorderColor: Color? {
        guard showsLeadingCategoryIcon else { return nil }
        return Color(hex: transaction.categoryColorHex)
    }
}
