//
//  File.swift
//  Xpnse
//
//  Created by Gokul C on 09/11/25.
//

import Foundation

extension Date {
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
}
