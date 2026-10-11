//
//  RecurringReminderCompletionValidator.swift
//  Xpnse
//

import Foundation

struct RecurringReminderCompletionValidator: JourneyCompletionValidator {
    func validate(context: CompletionValidationContext) -> CompletionValidationResult {
        if context.isReminderEnabled {
            return .valid
        }
        return .invalid(reason: .reminderNotEnabled)
    }
}
