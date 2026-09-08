//
//  JourneyCompletionValidator.swift
//  Xpnse
//

import Foundation

/// Verifies that a journey's intended outcome exists in the application before completing.
protocol JourneyCompletionValidator: Sendable {
    func validate(context: CompletionValidationContext) -> CompletionValidationResult
}
