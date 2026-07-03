//
//  TransactionType+BrandColor.swift
//  Xpnse
//

import SwiftUI

extension TransactionType {
    var brandColor: Color {
        iconFGColor.color
    }

    var brandHex: String {
        iconFGColor.brandHex
    }
}
