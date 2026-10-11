//
//  CompletionValidationResult.swift
//  Xpnse
//

import Foundation

/// Outcome of validating whether a journey's objective has been achieved.
enum CompletionValidationResult: Equatable, Sendable {
    case valid
    case invalid(reason: CompletionValidationFailureReason)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

/// Reason a completion validation failed. Primarily for debugging and unit tests.
enum CompletionValidationFailureReason: Equatable, Sendable {
    case incomeNotConfigured
    case noExpense
    case noCustomCategory
    case reminderNotEnabled
    case custom(String)
}
