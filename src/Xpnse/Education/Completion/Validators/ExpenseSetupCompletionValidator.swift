//
//  ExpenseSetupCompletionValidator.swift
//  Xpnse
//

import Foundation

struct ExpenseSetupCompletionValidator: JourneyCompletionValidator {
    func validate(context: CompletionValidationContext) -> CompletionValidationResult {
        if context.expenseCount > 0 {
            return .valid
        }
        return .invalid(reason: .noExpense)
    }
}
