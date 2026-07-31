//
//  Clock.swift
//  Xpnse
//

import Foundation

protocol Clock {
    func now() -> Date
}

struct SystemClock: Clock {
    func now() -> Date { Date() }
}

/// Mutable clock for unit tests.
final class ControllableClock: Clock {
    private var _now: Date

    init(now: Date = Date()) {
        _now = now
    }

    func now() -> Date { _now }

    func advance(by interval: TimeInterval) {
        _now = _now.addingTimeInterval(interval)
    }

    func set(_ date: Date) {
        _now = date
    }
}
