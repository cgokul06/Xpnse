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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(WidgetStyle.primaryText(for: colorScheme))
                .frame(width: 52, height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(WidgetStyle.elevatedFill(for: colorScheme))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            WidgetStyle.border(for: colorScheme),
                            lineWidth: WidgetStyle.borderWidth
                        )
                }

            Text("Add transaction")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WidgetStyle.primaryText(for: colorScheme))
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
            WidgetStyle.outlinedBackground {
                AddTransactionWidgetView()
            }
        }
        .configurationDisplayName("Add Transaction")
        .description("Jump straight to adding a transaction.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
