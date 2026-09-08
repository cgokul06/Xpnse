//
//  EducationSheetModel.swift
//  Xpnse
//

import Foundation

/// Hero icon for an education sheet (SF Symbol). Custom artwork uses the illustration slot on `EducationBottomSheet`.
enum EducationSheetIcon: Equatable, Sendable {
    case sfSymbol(String)
}

/// Presentation metadata for an education sheet button. Actions are supplied by the parent view.
struct EducationSheetButtonModel: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var accessibilityLabel: String?

    init(
        id: String = UUID().uuidString,
        title: String,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        accessibilityLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.accessibilityLabel = accessibilityLabel
    }
}

/// Campaign-agnostic content for `EducationBottomSheet`.
struct EducationSheetModel: Equatable, Identifiable, Sendable {
    let id: String
    var icon: EducationSheetIcon?
    let title: String
    let description: String
    var primaryButton: EducationSheetButtonModel
    var secondaryButton: EducationSheetButtonModel?
    var isDismissEnabled: Bool

    init(
        id: String = UUID().uuidString,
        icon: EducationSheetIcon? = nil,
        title: String,
        description: String,
        primaryButton: EducationSheetButtonModel,
        secondaryButton: EducationSheetButtonModel? = nil,
        isDismissEnabled: Bool = true
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.description = description
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.isDismissEnabled = isDismissEnabled
    }
}
