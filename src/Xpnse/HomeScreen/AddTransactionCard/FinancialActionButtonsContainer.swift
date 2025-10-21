//
//  AddTransactionButtonContainer.swift
//  Xpnse
//
//  Created by Gokul C on 25/07/25.
//

import SwiftUI

struct AddTransactionButtonContainer: View {
    let onAddExpense: () -> Void
    let onAddIncome: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            AddTransactionButton.addExpense(action: onAddExpense)
            AddTransactionButton.addIncome(action: onAddIncome)
        }
    }
}

#Preview {
    AddTransactionButtonContainer(onAddExpense: {}, onAddIncome: {})
}
