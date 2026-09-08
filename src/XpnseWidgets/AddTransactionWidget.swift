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
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsContainerBackground

    private var isTemplate: Bool {
        WidgetChromeMode.isTemplate(
            renderingMode: renderingMode,
            showsContainerBackground: showsContainerBackground
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            plusGlyph

            Text(L10n.tr("widget.add_transaction"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WidgetStyle.primaryText)
                .widgetAccentable()
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "\(AppGroupConstants.urlScheme)://add-transaction"))
    }

    @ViewBuilder
    private var plusGlyph: some View {
        if isTemplate {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.primary)
                .widgetAccentable()
                .frame(width: 52, height: 52)
        } else {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(WidgetStyle.primaryText)
                .frame(width: 52, height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(WidgetStyle.elevatedFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            WidgetStyle.border,
                            lineWidth: WidgetStyle.borderWidth
                        )
                }
        }
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
        .configurationDisplayName(LocalizedStringResource("widget.add.name"))
        .description(LocalizedStringResource("widget.add.description"))
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
