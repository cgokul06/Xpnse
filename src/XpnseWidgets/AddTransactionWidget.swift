//
//  AddTransactionWidget.swift
//  XpnseWidgets
//

import SwiftUI
import WidgetKit

struct AddTransactionWidgetEntry: TimelineEntry {
    let date: Date
}

struct AddTransactionWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> AddTransactionWidgetEntry {
        AddTransactionWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AddTransactionWidgetEntry) -> Void) {
        completion(AddTransactionWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AddTransactionWidgetEntry>) -> Void) {
        let entry = AddTransactionWidgetEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct AddTransactionWidgetView: View {
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(WidgetStyle.secondaryButton)
                    .frame(width: 52, height: 52)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Add transaction")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "\(AppGroupConstants.urlScheme)://add-transaction"))
    }
}

struct AddTransactionWidget: Widget {
    let kind = WidgetKinds.addTransaction

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AddTransactionWidgetProvider()) { _ in
            WidgetStyle.gradientBackground {
                AddTransactionWidgetView()
            }
        }
        .configurationDisplayName("Add Transaction")
        .description("Jump straight to adding a transaction.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
