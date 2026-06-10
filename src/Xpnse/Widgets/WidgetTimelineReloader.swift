//
//  WidgetTimelineReloader.swift
//  Xpnse
//

import WidgetKit

enum WidgetTimelineReloader {
    static func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
