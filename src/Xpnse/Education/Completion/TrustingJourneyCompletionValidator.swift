//
//  TrustingJourneyCompletionValidator.swift
//  Xpnse
//

import Foundation

/// Default validator that accepts any completion request. Preserves pre-validation behaviour.
struct TrustingJourneyCompletionValidator: JourneyCompletionValidator {
    func validate(context: CompletionValidationContext) -> CompletionValidationResult {
        .valid
    }
}
