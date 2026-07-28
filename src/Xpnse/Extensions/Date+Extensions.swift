//
//  Date+Extensions.swift
//  Xpnse
//

import Foundation

extension Date {
    func formattedDate(dateStyle: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = .current
        formatter.dateStyle = dateStyle
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    func formattedMonthYear() -> String {
        formatted(.dateTime.month(.abbreviated).year().locale(.current))
    }

    func formattedYear() -> String {
        formatted(.dateTime.year().locale(.current))
    }
}
