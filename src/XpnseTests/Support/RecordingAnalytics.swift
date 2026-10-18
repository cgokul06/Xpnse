//
//  RecordingAnalytics.swift
//  XpnseTests
//

import Foundation
@testable import Xpnse

final class RecordingAnalytics: AnalyticsLogging {
    struct Event: Equatable {
        var name: String
        var parameters: [String: String]
    }

    var events: [Event] = []
    var userProperties: [String: String?] = [:]

    func log(_ name: String, parameters: [String: String]) {
        events.append(Event(name: name, parameters: parameters))
    }

    func setUserProperty(_ value: String?, forName name: String) {
        userProperties[name] = value
    }

    func count(_ name: String) -> Int {
        events.filter { $0.name == name }.count
    }

    func count(_ name: String, result: String) -> Int {
        events.filter { $0.name == name && $0.parameters[AppAnalytics.Param.result] == result }.count
    }

    func events(named name: String) -> [Event] {
        events.filter { $0.name == name }
    }
}
