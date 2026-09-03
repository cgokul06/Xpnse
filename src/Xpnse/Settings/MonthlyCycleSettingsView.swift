//
//  MonthlyCycleSettingsView.swift
//  Xpnse
//

import SwiftUI

struct MonthlyCycleSettingsView: View {
    @ObservedObject private var store = MonthlyCycleStore.shared

    private var calendar: Calendar { .current }

    private var exampleText: String {
        let resolver = MonthlyCycleResolver(configuration: store.configuration, calendar: calendar)
        let cycle = resolver.currentCycle(for: Date())
        return MonthlyCycleFormatting.exampleRange(for: cycle)
    }

    var body: some View {
        List {
            Section {
                Picker(selection: startDayBinding) {
                    ForEach(MonthlyCycleConfiguration.allowedStartDays, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                } label: {
                    Text("settings.monthly_cycle.start_day")
                }
                .pickerStyle(.menu)
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.monthly_cycle.description")
                    Text(L10n.tr("settings.monthly_cycle.example", exampleText))
                    Text("settings.monthly_cycle.clamp_note")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .gradientNavigationBackground()
        .navigationTitle(L10n.tr("settings.monthly_cycle"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var startDayBinding: Binding<Int> {
        Binding(
            get: { store.configuration.startDay },
            set: { store.setStartDay($0) }
        )
    }
}
