//
//  AddTransactionButton.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct AddTransactionButton: View {
    let title: String
    let iconColor: Color
    let iconSymbol: String
    let action: () -> Void
    
    init(
        title: String,
        iconColor: Color,
        iconSymbol: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconColor = iconColor
        self.iconSymbol = iconSymbol
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    iconColor

                    Image(systemName: iconSymbol)
                        .font(.system(size: 24, weight: .bold))
                }
                .clipShape(Circle())
                .frame(height: 48)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                XpnseColorKey.addTransactionBG.color
            )
            .xpnseRoundedCorner()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Convenience initializers for common financial actions
extension AddTransactionButton {
    /// Creates an "Add Expense" button with red background and minus icon
    static func addExpense(action: @escaping () -> Void) -> AddTransactionButton {
        AddTransactionButton(
            title: "Add Expense",
            iconColor: XpnseColorKey.expensePrimary.color,
            iconSymbol: "minus",
            action: action
        )
    }
    
    /// Creates an "Add Income" button with green background and plus icon
    static func addIncome(action: @escaping () -> Void) -> AddTransactionButton {
        AddTransactionButton(
            title: "Add Income",
            iconColor: XpnseColorKey.incomePrimary.color,
            iconSymbol: "plus",
            action: action
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        // Preview individual buttons
        VStack(spacing: 16) {
            AddTransactionButton.addExpense {
                print("Add Expense tapped")
            }
            
            AddTransactionButton.addIncome {
                print("Add Income tapped")
            }
        }
        .padding()
    }
    .background(Color.black)
}
