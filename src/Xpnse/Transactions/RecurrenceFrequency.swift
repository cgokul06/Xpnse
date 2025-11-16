import Foundation

/// Represents recurrence frequencies with their parameters.
public enum RecurrenceFrequency: Codable, Hashable, Sendable {
    /// Monthly recurrence on a specified day with overflow adjustment.
    /// - Parameters:
    ///   - day: The desired day of month (1...31).
    ///   - overflow: How to handle months where the day does not exist.
    case monthly(day: Int, overflow: MonthOverflowAdjustment)

    /// Weekly recurrence on specified weekdays.
    /// - Parameter days: Array of weekdays on which the recurrence happens.
    case weeklyOn(days: [Weekday])
    
    /// Recurrence once in every specified number of days.
    /// - Parameter days: Interval in days between occurrences; minimum is 1.
    case onceInEvery(days: Int)

    /// Factory method to create `.monthly` safely clamping the day into 1...31.
    /// - Parameters:
    ///   - day: Desired day of month (any Int, will be clamped).
    ///   - overflow: Overflow adjustment behavior.
    /// - Returns: A `RecurrenceFrequency.monthly` value with clamped day.
    public static func monthlySafe(day: Int, overflow: MonthOverflowAdjustment) -> RecurrenceFrequency {
        let clampedDay = min(max(day, 1), 31)
        return .monthly(day: clampedDay, overflow: overflow)
    }

    /// Factory method to create `.weeklyOn` safely by deduplicating and sorting days.
    /// - Parameter days: Array of weekdays.
    /// - Returns: A `RecurrenceFrequency.weeklyOn` value with unique sorted days, or defaults to Monday if empty.
    public static func weeklyOnSafe(days: [Weekday]) -> RecurrenceFrequency {
        let unique = Array(Set(days)).sorted(by: { $0.rawValue < $1.rawValue })
        if unique.isEmpty { return .weeklyOn(days: [.monday]) }
        return .weeklyOn(days: unique)
    }

    /// Factory method to create `.onceInEvery` safely clamping the interval to at least 1 day.
    /// - Parameter days: The recurrence interval in days.
    /// - Returns: A `RecurrenceFrequency.onceInEvery` value with at least 1 day interval.
    public static func onceInEverySafe(days: Int) -> RecurrenceFrequency {
        let d = max(1, days)
        return .onceInEvery(days: d)
    }

    /// Returns the first occurrence of the recurrence on or after the given start date.
    /// The time components (hour, minute, second, nanosecond) of `start` are preserved.
    /// - Parameters:
    ///   - start: The date from which to find the first occurrence.
    ///   - calendar: The calendar to use. Defaults to `.current`.
    /// - Returns: The first occurrence date on or after `start`, or `nil` if it cannot be computed.
    public func firstOccurrence(onOrAfter start: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case let .monthly(day, overflow):
            return RecurrenceFrequency.computeMonthlyOccurrence(
                from: start,
                day: day,
                overflow: overflow,
                calendar: calendar,
                inclusive: true
            )
        case let .weeklyOn(days):
            return RecurrenceFrequency.computeWeeklyOccurrence(
                from: start,
                days: days,
                calendar: calendar,
                inclusive: true
            )
        case let .onceInEvery(n):
            return RecurrenceFrequency.computeEveryNDaysOccurrence(
                from: start,
                intervalDays: n,
                calendar: calendar,
                inclusive: true
            )
        }
    }

    /// Returns the next occurrence that is strictly after the given date.
    /// The time components of `date` are preserved.
    /// - Parameters:
    ///   - date: The date after which to find the next occurrence.
    ///   - calendar: The calendar to use. Defaults to `.current`.
    /// - Returns: The next occurrence date strictly after `date`, or `nil` if it cannot be computed.
    public func nextOccurrence(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case let .monthly(day, overflow):
            return RecurrenceFrequency.computeMonthlyOccurrence(
                from: date,
                day: day,
                overflow: overflow,
                calendar: calendar,
                inclusive: false
            )
        case let .weeklyOn(days):
            return RecurrenceFrequency.computeWeeklyOccurrence(
                from: date,
                days: days,
                calendar: calendar,
                inclusive: false
            )
        case let .onceInEvery(n):
            return RecurrenceFrequency.computeEveryNDaysOccurrence(
                from: date,
                intervalDays: n,
                calendar: calendar,
                inclusive: false
            )
        }
    }
}

// MARK: - Private recurrence logic for monthly, weekly and onceInEvery cases
extension RecurrenceFrequency {
    /// Compute the next monthly occurrence based on inclusive flag.
    private static func computeMonthlyOccurrence(
        from base: Date,
        day: Int,
        overflow: MonthOverflowAdjustment,
        calendar: Calendar,
        inclusive: Bool
    ) -> Date? {
        // Extract time components from base
        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: base)

        // Extract year and month from base
        var yearMonth = calendar.dateComponents([.year, .month], from: base)
        guard let year = yearMonth.year, let month = yearMonth.month else { return nil }

        // Try target date in current month
        if let candidate = dateFor(year: year, month: month, day: day, overflow: overflow, calendar: calendar, timeComponents: timeComponents) {
            if inclusive {
                if candidate >= base { return candidate }
            } else {
                if candidate > base { return candidate }
            }
        }

        // Otherwise, move to next month
        var nextMonth = month + 1
        var nextYear = year
        if nextMonth > 12 {
            nextMonth = 1
            nextYear += 1
        }

        return dateFor(
            year: nextYear,
            month: nextMonth,
            day: day,
            overflow: overflow,
            calendar: calendar,
            timeComponents: timeComponents
        )
    }

    /// Helper to create a Date for given year, month, and day with overflow adjustment.
    /// The time components are applied to the returned date.
    private static func dateFor(
        year: Int,
        month: Int,
        day: Int,
        overflow: MonthOverflowAdjustment,
        calendar: Calendar,
        timeComponents: DateComponents
    ) -> Date? {
        // Determine valid day for the given month and year
        let range = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: year, month: month))!)!

        let validDay: Int
        if range.contains(day) {
            validDay = day
        } else {
            // Overflow adjustments
            switch overflow {
            case .lastDayOfMonth:
                validDay = range.upperBound - 1
            case .firstDayOfNextMonth:
                // We will handle next month day 1 separately
                // Return nil here to signal out of range and handle outside
                return dateForNextMonthFirstDay(year: year, month: month, calendar: calendar, timeComponents: timeComponents)
            }
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = validDay
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        components.nanosecond = timeComponents.nanosecond

        return calendar.date(from: components)
    }

    /// Helper to create a Date for the first day of the month after the given year and month.
    private static func dateForNextMonthFirstDay(
        year: Int,
        month: Int,
        calendar: Calendar,
        timeComponents: DateComponents
    ) -> Date? {
        var nextMonth = month + 1
        var nextYear = year
        if nextMonth > 12 {
            nextMonth = 1
            nextYear += 1
        }

        var components = DateComponents()
        components.year = nextYear
        components.month = nextMonth
        components.day = 1
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        components.nanosecond = timeComponents.nanosecond

        return calendar.date(from: components)
    }

    /// Compute the next weekly occurrence based on inclusive flag.
    private static func computeWeeklyOccurrence(
        from base: Date,
        days: [Weekday],
        calendar: Calendar,
        inclusive: Bool
    ) -> Date? {
        // Preserve time from base
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: base)
        // Current weekday in Calendar (1=Sunday ... 7=Saturday)
        let currentWeekday = calendar.component(.weekday, from: base)

        // Prepare sorted unique weekday integers corresponding to Calendar
        let targetWeekdays = Array(Set(days)).map { $0.rawValue }.sorted()
        if targetWeekdays.isEmpty { return nil }

        // Helper to build date for a given weekday delta
        func dateByAdding(days delta: Int) -> Date? {
            guard let dayShift = calendar.date(byAdding: .day, value: delta, to: base) else { return nil }
            var comps = calendar.dateComponents([.year, .month, .day], from: dayShift)
            comps.hour = time.hour; comps.minute = time.minute; comps.second = time.second; comps.nanosecond = time.nanosecond
            return calendar.date(from: comps)
        }

        // Compute the smallest non-negative delta (inclusive) or strictly positive delta (exclusive)
        var bestDelta: Int? = nil
        for w in targetWeekdays {
            // Distance in days to target weekday within the same week cycle
            var delta = (w - currentWeekday + 7) % 7
            if inclusive {
                // allow delta == 0 only if time >= base time comparison; since we preserve time, check date comparison after constructing
            } else {
                if delta == 0 { delta = 7 }
            }
            if bestDelta == nil || delta < bestDelta! { bestDelta = delta }
        }

        guard var delta = bestDelta else { return nil }

        // If inclusive and delta == 0, ensure resulting candidate >= base; if not, move to next available weekday
        if inclusive && delta == 0 {
            if let candidate = dateByAdding(days: 0) {
                if candidate >= base { return candidate }
            }
            // Need the next scheduled weekday after today
            // Find the next weekday strictly after currentWeekday in the target list
            if let nextW = targetWeekdays.first(where: { $0 > currentWeekday }) {
                delta = (nextW - currentWeekday + 7) % 7
            } else {
                // wrap to first in list next week
                delta = (targetWeekdays.first! - currentWeekday + 7) % 7
                if delta == 0 { delta = 7 }
            }
        }

        return dateByAdding(days: delta)
    }
    
    /// Compute the next occurrence for `.onceInEvery(days:)` based on inclusive flag.
    private static func computeEveryNDaysOccurrence(
        from base: Date,
        intervalDays: Int,
        calendar: Calendar,
        inclusive: Bool
    ) -> Date? {
        let interval = max(1, intervalDays)
        // Preserve time from base
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: base)
        let startOfBaseDay = calendar.startOfDay(for: base)

        // If inclusive, candidate can be today if time >= base time (we preserve time, so compare full Date)
        if inclusive {
            // Today as candidate
            var comps = calendar.dateComponents([.year, .month, .day], from: base)
            comps.hour = time.hour; comps.minute = time.minute; comps.second = time.second; comps.nanosecond = time.nanosecond
            if let todayCandidate = calendar.date(from: comps), todayCandidate >= base {
                return todayCandidate
            }
        }

        // Compute days to add to reach the next occurrence boundary.
        // We treat the schedule as repeating every `interval` days relative to the base day.
        // Find offset from a reference: use startOfBaseDay modulo interval.
        // Next multiple after today is: startOfBaseDay + k*interval such that result > base (or >= when inclusive was already tested).
        // Compute remainder days since a reference epoch (e.g., 1970-01-01) and align to interval.
        let reference = Date(timeIntervalSince1970: 0)
        let daysSinceRef = calendar.dateComponents([.day], from: calendar.startOfDay(for: reference), to: startOfBaseDay).day ?? 0
        let remainder = ((daysSinceRef % interval) + interval) % interval
        let daysToNextMultiple = (interval - remainder) % interval

        // If daysToNextMultiple == 0, we already tested inclusive today; so move by interval days
        let deltaDays = (daysToNextMultiple == 0) ? interval : daysToNextMultiple

        guard let shiftedDay = calendar.date(byAdding: .day, value: deltaDays, to: startOfBaseDay) else { return nil }
        var comps = calendar.dateComponents([.year, .month, .day], from: shiftedDay)
        comps.hour = time.hour; comps.minute = time.minute; comps.second = time.second; comps.nanosecond = time.nanosecond
        return calendar.date(from: comps)
    }
}

/// Defines how to adjust the day when the specified day of month
/// does not exist in the target month (e.g., 29, 30, 31 in shorter months).
public enum MonthOverflowAdjustment: String, Codable, Sendable {
    /// Use the last valid day of the target month.
    case lastDayOfMonth
    /// Use the first day of the next month.
    case firstDayOfNextMonth
}

/// Represents weekdays with raw values aligned to Calendar component `.weekday`.
public enum Weekday: Int, Codable, Hashable, Sendable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
}
