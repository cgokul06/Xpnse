//
//  SharedTextTransactionAnalysis.swift
//  Xpnse
//

import Foundation
import FoundationModels

/// Foundation Models result for shared plain text (Share Extension → Add Transaction).
@Generable
struct SharedTextTransactionAnalysis: Equatable {
    @Guide(description: "True only if the text describes a financial transaction such as a purchase, payment, transfer, bill, refund, income, or savings movement. False for unrelated notes, chats, or articles.")
    var isTransactionRelated: Bool

    @Guide(description: "Transaction type when related; use expense if unsure.")
    var type: TransactionType

    @Guide(description: "True only if the text clearly names or implies a specific category (e.g. food, transport). False when category is absent or ambiguous — do not guess.")
    var categoryFoundInText: Bool

    @Guide(description: "Category id from the allowed list only when categoryFoundInText is true; otherwise use the type default id from the prompt.")
    var categoryId: String

    @Guide(description: "Total amount when related; otherwise 0.")
    var amount: Double

    @Guide(description: "True only if an explicit calendar date appears in the text. False when no date is mentioned — do not invent dates.")
    var dateFoundInText: Bool

    @Guide(description: "Date string only when dateFoundInText is true; otherwise use today's date as yyyy-MM-dd.")
    var date: String

    @Guide(description: "True only if the text includes an explicit merchant, payee, or short description separate from the amount. False when none is stated — leave title empty; do not invent.")
    var titleFoundInText: Bool

    @Guide(description: "Title max 25 characters only when titleFoundInText is true; otherwise empty string.")
    var title: String

    var items: [TransactionItem]

    @Guide(description: "Location if available")
    var location: String?

    var tags: [String]

    var currency: CurrencyOption

    @Guide(description: "Date format like 'dd/MM/yy' when dateFoundInText is true; otherwise 'yyyy-MM-dd'.")
    var dateFormat: String

    func asScannedTransaction() -> ScannedTransaction {
        ScannedTransaction(
            type: type,
            categoryId: categoryId,
            amount: amount,
            date: date,
            title: title,
            items: items,
            location: location,
            tags: tags,
            currency: currency,
            dateFormat: dateFormat
        )
    }
}
