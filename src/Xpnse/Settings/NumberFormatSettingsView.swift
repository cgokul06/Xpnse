//
//  NumberFormatSettingsView.swift
//  Xpnse
//

import SwiftUI

struct NumberFormatSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedPreference = NumberFormatPreference.current

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(NumberFormatPreference.allCases, id: \.self) { preference in
                    Button {
                        select(preference)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title(for: preference))
                                    .font(.system(size: 16, weight: .semibold))
                                    .xpnseAdaptiveForeground()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(subtitle(for: preference))
                                    .font(.system(size: 13, weight: .regular))
                                    .xpnseAdaptiveForeground(muted: true)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if preference == selectedPreference {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .xpnseAdaptiveForeground()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 12)
                        .background(
                            AdaptiveBrandSurface.rowBackground(
                                for: colorScheme,
                                emphasized: preference == selectedPreference
                            )
                        )
                        .xpnseRoundedCorner()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .gradientNavigationBackground()
        .navigationTitle(L10n.tr("settings.number_format"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func select(_ preference: NumberFormatPreference) {
        NumberFormatPreference.set(preference)
        selectedPreference = preference
        WidgetTimelineReloader.reloadAll()
    }

    private func title(for preference: NumberFormatPreference) -> String {
        switch preference {
        case .auto:
            return L10n.tr("settings.number_format.auto")
        case .lakhCrore:
            return L10n.tr("settings.number_format.lakh_crore")
        case .million:
            return L10n.tr("settings.number_format.million")
        }
    }

    private func subtitle(for preference: NumberFormatPreference) -> String {
        switch preference {
        case .auto:
            return L10n.tr("settings.number_format.auto_subtitle")
        case .lakhCrore:
            return L10n.tr("settings.number_format.lakh_crore_subtitle")
        case .million:
            return L10n.tr("settings.number_format.million_subtitle")
        }
    }
}
