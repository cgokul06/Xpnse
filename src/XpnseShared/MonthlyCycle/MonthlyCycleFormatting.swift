//
//  MonthlyCycleFormatting.swift
//  XpnseShared
//

import Foundation

enum MonthlyCycleFormatting {
    /// Home / widget period title. Start day 1 matches the previous `MMM yyyy` label.
    static func periodTitle(
        for cycle: BillingCycle,
        configuration: MonthlyCycleConfiguration,
        locale: Locale = .current,
        rangeSeparator: String = " – "
    ) -> String {
        let config = configuration.clamped
        if config.kind == .fixedStartDay, config.startDay == 1 {
            return monthYear(cycle.start, calendar: cycle.calendar, locale: locale)
        }
        return rangeTitle(
            start: cycle.start,
            end: cycle.endDate,
            calendar: cycle.calendar,
            locale: locale,
            separator: rangeSeparator
        )
    }

    /// Settings example, e.g. `26 Aug → 25 Sep`.
    static func exampleRange(
        for cycle: BillingCycle,
        locale: Locale = .current
    ) -> String {
        rangeTitle(
            start: cycle.start,
            end: cycle.endDate,
            calendar: cycle.calendar,
            locale: locale,
            separator: " → ",
            includeYear: false
        )
    }

    /// Chart legend: `Aug` when start day is 1, otherwise `Aug–Sep`.
    static func chartSeriesLabel(
        for cycle: BillingCycle,
        configuration: MonthlyCycleConfiguration,
        locale: Locale = .current
    ) -> String {
        let config = configuration.clamped
        if config.kind == .fixedStartDay, config.startDay == 1 {
            return abbreviatedMonth(cycle.start, calendar: cycle.calendar, locale: locale)
        }
        let startMonth = abbreviatedMonth(cycle.start, calendar: cycle.calendar, locale: locale)
        let endMonth = abbreviatedMonth(cycle.endDate, calendar: cycle.calendar, locale: locale)
        if startMonth == endMonth {
            return startMonth
        }
        return "\(startMonth)–\(endMonth)"
    }

    private static func monthYear(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        var style = Date.FormatStyle()
            .month(.abbreviated)
            .year()
            .locale(locale)
        style.calendar = calendar
        return date.formatted(style)
    }

    private static func rangeTitle(
        start: Date,
        end: Date,
        calendar: Calendar,
        locale: Locale,
        separator: String,
        includeYear: Bool = true
    ) -> String {
        let startYear = calendar.component(.year, from: start)
        let endYear = calendar.component(.year, from: end)
        let yearsDiffer = startYear != endYear

        if yearsDiffer {
            return dayMonthYear(start, calendar: calendar, locale: locale)
                + separator
                + dayMonthYear(end, calendar: calendar, locale: locale)
        }

        if includeYear {
            return dayMonth(start, calendar: calendar, locale: locale)
                + separator
                + dayMonth(end, calendar: calendar, locale: locale)
                + " \(startYear)"
        }

        return dayMonth(start, calendar: calendar, locale: locale)
            + separator
            + dayMonth(end, calendar: calendar, locale: locale)
    }

    private static func dayMonth(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        var style = Date.FormatStyle()
            .day()
            .month(.abbreviated)
            .locale(locale)
        style.calendar = calendar
        return date.formatted(style)
    }

    private static func abbreviatedMonth(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        var style = Date.FormatStyle()
            .month(.abbreviated)
            .locale(locale)
        style.calendar = calendar
        return date.formatted(style)
    }

    private static func dayMonthYear(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        var style = Date.FormatStyle()
            .day()
            .month(.abbreviated)
            .year()
            .locale(locale)
        style.calendar = calendar
        return date.formatted(style)
    }
}
