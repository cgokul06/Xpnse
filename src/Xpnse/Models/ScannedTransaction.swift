//
//  ScannedTransaction.swift
//  Xpnse
//
//  Created by Gokul C on 26/10/25.
//

import Foundation
import FoundationModels

@Generable
struct ScannedTransaction: Codable, Equatable {
    var type: TransactionType
    var category: TransactionCategory
    @Guide(description: "The total transaction amount")
    var amount: Double
    @Guide(description: "The date string on which the transaction has happened")
    var date: String
    @Guide(description: "The generic title of the transaction with minimal details max 25 characters.")
    var title: String
    var items: [TransactionItem]
    @Guide(description: "The location of transaction if available")
    var location: String?
    var tags: [String]
    var currency: CurrencyOption
    @Guide(description: "The string format in which date is represented like 'dd/MM/yy'")
    var dateFormat: String

    /// Converts `date` string into a `Date` using `dateFormat`.
    var formattedDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale(identifier: "en_US_POSIX") // ensures consistent parsing
        formatter.timeZone = TimeZone.current

        // Try parsing the string
        if let parsedDate = formatter.date(from: date) {
            return parsedDate
        } else {
            // fallback: return current date if parsing fails
            print("⚠️ Failed to parse date '\(date)' with format '\(dateFormat)'")
            return Date()
        }
    }
}
