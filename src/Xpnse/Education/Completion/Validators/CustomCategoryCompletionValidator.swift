//
//  CustomCategoryCompletionValidator.swift
//  Xpnse
//

import Foundation

struct CustomCategoryCompletionValidator: JourneyCompletionValidator {
    func validate(context: CompletionValidationContext) -> CompletionValidationResult {
        if context.customCategoryCount > 0 {
            return .valid
        }
        return .invalid(reason: .noCustomCategory)
    }
}
