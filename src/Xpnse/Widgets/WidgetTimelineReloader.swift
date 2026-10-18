//
//  WidgetTimelineReloader.swift
//  Xpnse
//

import WidgetKit

enum WidgetTimelineReloader {
    static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func reloadBalance() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKinds.balance)
    }
}
