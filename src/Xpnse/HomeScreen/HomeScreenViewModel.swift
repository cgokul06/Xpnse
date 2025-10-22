//
//  HomeScreenViewModel.swift
//  Xpnse
//
//  Created by Gokul C on 22/10/25.
//

import Combine
import Foundation

enum CalendarComparison: Int {
    case fortnightly = 1 // once in two weeks
    case monthly = 2
    case yearly = 3
}

final class HomeScreenViewModel: ObservableObject {
    @Published var currentCalendarComparator: CalendarComparison
    @Published private(set) var startDate: Date?
    @Published private(set) var endDate: Date?
    @Published private(set) var id: String = ""

    init() {
        let currentSelection = UserDefaultsHelper.shared.integer(forKey: .calendarAggregator)
        if let val = CalendarComparison(rawValue: currentSelection) {
            self.currentCalendarComparator = val
        } else {
            self.currentCalendarComparator = .monthly
        }

        self.setupStartAndEndDate()
    }

    func setCalendarComparator(_ comparator: CalendarComparison) {
        self.currentCalendarComparator = comparator
        UserDefaultsHelper.shared.set(comparator.rawValue, forKey: .calendarAggregator)
    }

    private func setupStartAndEndDate() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let today = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!

        switch self.currentCalendarComparator {
        case .fortnightly:
            // Start of the current year
            guard let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: today)) else { return }

            // Number of days since Jan 1
            let daysSinceStart = calendar.dateComponents([.day], from: startOfYear, to: today).day ?? 0

            // Fortnight index (0 to 25)
            let fortnightIndex = daysSinceStart / 14

            // Start date = Jan 1 + (fortnightIndex * 14) days
            guard let fortnightStart = calendar.date(byAdding: .day, value: fortnightIndex * 14, to: startOfYear) else { return }

            // End date = start + 13 days (14-day range)
            guard let fortnightEnd = calendar.date(byAdding: .day, value: 13, to: fortnightStart) else { return }

            self.startDate = fortnightStart
            self.endDate = min(fortnightEnd, today) // Use today if current period is ongoing

        case .monthly:
            guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else { return }
            self.startDate = startOfMonth

            if let range = calendar.range(of: .day, in: .month, for: today),
               let endOfMonth = calendar.date(bySetting: .day, value: range.count, of: startOfMonth) {
                self.endDate = min(endOfMonth, today)
            } else {
                self.endDate = today
            }

        case .yearly:
            guard let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: today)) else { return }
            self.startDate = startOfYear
            self.endDate = today
        }

        self.id = "\(self.startDate?.timeIntervalSince1970 ?? 0)\(self.endDate?.timeIntervalSince1970 ?? 0)"
    }
}
