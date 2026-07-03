//
//  Double+Extensions.swift
//  Xpnse
//
//  Created by Gokul C on 09/05/26.
//

import Foundation

extension Double {
    /// Formats large numbers using floor-based abbreviated units.
    /// Units follow: K (thousand), L (lakh), M (million), C (crore).
    /// Example: 20543 -> 20.5K (for decimals = 1), 9812345 -> 98.1L.
    func abbreviatedFloor(decimals: Int = 2) -> String {
        AmountFormatter.abbreviatedFloor(self, decimals: decimals)
    }
}

