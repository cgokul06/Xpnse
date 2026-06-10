//
//  FoundationModelsAvailability.swift
//  Xpnse
//

import FoundationModels

enum FoundationModelsAvailability {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    static var unavailabilityMessage: String? {
        guard case .unavailable(let reason) = SystemLanguageModel.default.availability else {
            return nil
        }

        switch reason {
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Please enable it in Settings."
        case .deviceNotEligible:
            return "This device is not eligible for Apple Intelligence. Please use a compatible device."
        case .modelNotReady:
            return "The language model is not ready yet. Please try again later."
        @unknown default:
            return "The language model is unavailable for an unknown reason."
        }
    }
}
