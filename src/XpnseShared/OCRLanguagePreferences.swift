//
//  OCRLanguagePreferences.swift
//  XpnseShared
//

import Foundation

/// Vision OCR language tags derived from the device locale.
/// Extend `supportedRecognitionLanguages` when adding locales later.
enum OCRLanguagePreferences {
    /// BCP-47-ish tags accepted by Vision text recognition.
    static let supportedRecognitionLanguages: Set<String> = [
        "en-US", "es-ES", "fr-FR", "de-DE",
        "it-IT", "pt-BR", "nl-NL", "ja-JP", "ko-KR", "zh-Hans"
    ]

    /// Ordered list: current locale match first, then English fallback.
    static func recognitionLanguages(for locale: Locale = .current) -> [String] {
        var languages: [String] = []

        if let match = bestMatch(for: locale) {
            languages.append(match)
        }

        let english = "en-US"
        if !languages.contains(english) {
            languages.append(english)
        }
        return languages
    }

    private static func bestMatch(for locale: Locale) -> String? {
        let lang = locale.language.languageCode?.identifier.lowercased() ?? "en"
        let region = locale.region?.identifier.uppercased()

        if let region {
            let tagged = "\(lang)-\(region)"
            if let exact = supportedRecognitionLanguages.first(where: {
                $0.compare(tagged, options: .caseInsensitive) == .orderedSame
            }) {
                return exact
            }
        }

        return supportedRecognitionLanguages.first {
            $0.lowercased().hasPrefix("\(lang)-") || $0.lowercased() == lang
        }
    }
}
