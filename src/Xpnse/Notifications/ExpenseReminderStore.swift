//
//  ExpenseReminderStore.swift
//  Xpnse
//

import Foundation

protocol ExpenseReminderStoring: AnyObject {
    var isEnabled: Bool { get set }
    var lastActiveAt: Date? { get set }
    var lastScheduledReminderAt: Date? { get set }
    var lastReminderDeliveredAt: Date? { get set }
    var campaignVersion: Int { get set }
    var didAttemptProvisionalAuthorization: Bool { get set }
    var analyticsSignatures: [String: String] { get set }
    /// Pending `check_in_conversion` attribution from the latest observed notification tap.
    var conversionAttribution: ExpenseReminderConversionAttribution? { get set }
}

/// Minimal marker: the campaign that was tapped and when attribution lapses. No transaction data.
struct ExpenseReminderConversionAttribution: Codable, Equatable {
    var campaignVersion: Int
    var expiresAt: Date
}

final class UserDefaultsExpenseReminderStore: ExpenseReminderStoring {
    private let defaults: UserDefaultsHelper

    init(defaults: UserDefaultsHelper = .shared) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get {
            guard defaults.object(forKey: .expenseReminderEnabled) != nil else { return true }
            return defaults.bool(forKey: .expenseReminderEnabled)
        }
        set {
            defaults.set(newValue, forKey: .expenseReminderEnabled)
        }
    }

    var lastActiveAt: Date? {
        get { date(forKey: .expenseReminderLastActiveAt) }
        set { set(newValue, forKey: .expenseReminderLastActiveAt) }
    }

    var lastScheduledReminderAt: Date? {
        get { date(forKey: .expenseReminderLastScheduledAt) }
        set { set(newValue, forKey: .expenseReminderLastScheduledAt) }
    }

    var lastReminderDeliveredAt: Date? {
        get { date(forKey: .expenseReminderLastDeliveredAt) }
        set { set(newValue, forKey: .expenseReminderLastDeliveredAt) }
    }

    var campaignVersion: Int {
        get { defaults.integer(forKey: .expenseReminderCampaignVersion) }
        set { defaults.set(newValue, forKey: .expenseReminderCampaignVersion) }
    }

    var didAttemptProvisionalAuthorization: Bool {
        get { defaults.bool(forKey: .expenseReminderDidAttemptProvisionalAuthorization) }
        set { defaults.set(newValue, forKey: .expenseReminderDidAttemptProvisionalAuthorization) }
    }

    var analyticsSignatures: [String: String] {
        get {
            guard let data = defaults.data(forKey: .expenseReminderAnalyticsSignatures),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.setData(data, forKey: .expenseReminderAnalyticsSignatures)
        }
    }

    var conversionAttribution: ExpenseReminderConversionAttribution? {
        get {
            guard let data = defaults.data(forKey: .expenseReminderConversionAttribution) else { return nil }
            return try? JSONDecoder().decode(ExpenseReminderConversionAttribution.self, from: data)
        }
        set {
            defaults.setData(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: .expenseReminderConversionAttribution)
        }
    }

    private func date(forKey key: UserDefaultsKey) -> Date? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: key))
    }

    private func set(_ date: Date?, forKey key: UserDefaultsKey) {
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: key)
        } else {
            defaults.remove(forKey: key)
        }
    }
}
