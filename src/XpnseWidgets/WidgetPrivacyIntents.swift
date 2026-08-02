//
//  WidgetPrivacyIntents.swift
//  XpnseWidgets
//

import AppIntents

/// Temporarily reveals financial values on home screen widgets (~30 seconds).
struct RevealWidgetDataIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.show"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetPrivacyManager.reveal()
        WidgetPrivacyManager.reloadAllWidgets()
        return .result()
    }
}

/// Immediately hides financial values on home screen widgets.
struct HideWidgetDataIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.hide"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetPrivacyManager.hide()
        WidgetPrivacyManager.reloadAllWidgets()
        return .result()
    }
}
