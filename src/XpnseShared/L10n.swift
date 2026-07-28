//
//  L10n.swift
//  XpnseShared
//

import Foundation

/// Thin helpers for non-View call sites. Prefer `Text("key")` / `String(localized:)` in UI.
enum L10n {
    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .main)
    }

    /// Lookup by semantic key (manual catalog entries).
    static func tr(_ key: String) -> String {
        String(localized: String.LocalizationValue(stringLiteral: key))
    }

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = String(localized: String.LocalizationValue(stringLiteral: key))
        return String(format: format, locale: .current, arguments: args)
    }

    /// Preferred language name for AI prompts (English fallback).
    static var preferredLanguageNameForPrompts: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return Locale.current.localizedString(forLanguageCode: code) ?? "English"
    }

    static var preferredLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }
}
