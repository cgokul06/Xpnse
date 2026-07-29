//
//  LegalDocument.swift
//  Xpnse
//

import Foundation

/// Public legal documents hosted on GitHub Pages.
enum LegalDocument: String, Identifiable {
    case privacyPolicy
    case termsAndConditions

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .privacyPolicy:
            "settings.privacy_policy"
        case .termsAndConditions:
            "settings.terms_conditions"
        }
    }

    var url: URL {
        switch self {
        case .privacyPolicy:
            URL(string: "https://cgokul06.github.io/snapledger-legal/privacy.html")!
        case .termsAndConditions:
            URL(string: "https://cgokul06.github.io/snapledger-legal/terms.html")!
        }
    }
}
