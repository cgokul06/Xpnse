//
//  IncomeSetupCompletionValidator.swift
//  Xpnse
//

import Foundation

struct IncomeSetupCompletionValidator: JourneyCompletionValidator {
    func validate(context: CompletionValidationContext) -> CompletionValidationResult {
        if context.hasConfiguredIncome || context.hasRecurringIncome {
            return .valid
        }
        return .invalid(reason: .incomeNotConfigured)
    }
}
