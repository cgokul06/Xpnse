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
            return L10n.tr("ai.unavailable.not_enabled")
        case .deviceNotEligible:
            return L10n.tr("ai.unavailable.device_not_eligible")
        case .modelNotReady:
            return L10n.tr("ai.unavailable.model_not_ready")
        @unknown default:
            return L10n.tr("ai.unavailable.unknown")
        }
    }
}
