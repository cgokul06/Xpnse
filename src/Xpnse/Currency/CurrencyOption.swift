//
//  CurrencyOption.swift
//  Xpnse
//
//  Created by Gokul C on 14/09/25.
//

import Foundation
import FoundationModels

@Generable(description: "A currency option")
struct CurrencyOption: Identifiable, Codable, Hashable {
    let id: Int
    let code: String
    let name: String
    let symbol: String
    
    var displayName: String {
        "\(symbol) \(code)"
    }
}
