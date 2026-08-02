//
//  Double+Extensions.swift
//  Xpnse
//
//  Created by Gokul C on 09/05/26.
//

import Foundation

extension Double {
    /// Compact number abbreviation via the shared locale-aware formatter.
    func abbreviatedFloor(decimals: Int = 2) -> String {
        AmountFormatter.abbreviatedFloor(self, decimals: decimals)
    }
}

