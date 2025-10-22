//
//  SummaryCardView.swift
//  Xpnse
//
//  Created by Gokul C on 21/07/25.
//

import SwiftUI

// MARK: - Financial Summary Card View

struct SummaryCardView: View {
    let totalBalance: Double
    let income: Double
    let expenses: Double
    
    init(totalBalance: Double = 3542.15, income: Double = 5240.00, expenses: Double = 1697.85) {
        self.totalBalance = totalBalance
        self.income = income
        self.expenses = expenses
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Top Section - Total Balance
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Balance")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("\(CurrencyManager.shared.selectedCurrency.symbol) \(totalBalance, specifier: "%.2f")")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Transfer Button
                Button(action: {
                    // Handle transfer action
                    print("Transfer button tapped")
                }) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            XpnseColorKey.transactionsButton.color
                        )
                        .clipShape(Circle())
                }
            }

            // Bottom Section - Income and Expenses
            HStack(spacing: 12) {
                // Income Section
                ExpenseComponent(type: .income, cash: income)
                    .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 60)

                // Expenses Section
                ExpenseComponent(type: .expense, cash: expenses)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            XpnseColorKey.summaryCard.color
        )
        .xpnseRoundedCorner(16)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 8)
    }
}

// MARK: - Preview

struct SummaryCardView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Financial Summary Card")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                SummaryCardView()
            }
            .padding(.horizontal, 16)
        }
    }
}
