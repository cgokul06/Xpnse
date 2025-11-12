//
//  SuggestionItem.swift
//  Xpnse
//
//  Created by Gokul C on 09/11/25.
//

import Foundation

//public struct SuggestionItem: Hashable, Codable {
//        public let title: String
//        public let categoryIdentifier: String?
//        public let frequency: Int
//        public let lastUsed: Date
//        public let normalized: String
//        
//        public init(title: String, categoryIdentifier: String?, frequency: Int, lastUsed: Date) {
//            self.title = title
//            self.categoryIdentifier = categoryIdentifier
//            self.frequency = frequency
//            self.lastUsed = lastUsed
//            self.normalized = SuggestionEngine.normalize(title)
//        }
//        
//        public func hash(into hasher: inout Hasher) {
//            hasher.combine(title)
//            hasher.combine(categoryIdentifier)
//            hasher.combine(frequency)
//            hasher.combine(lastUsed)
//            hasher.combine(normalized)
//        }
//        
//        public static func == (lhs: SuggestionItem, rhs: SuggestionItem) -> Bool {
//            return lhs.title == rhs.title &&
//                lhs.categoryIdentifier == rhs.categoryIdentifier &&
//                lhs.frequency == rhs.frequency &&
//                lhs.lastUsed == rhs.lastUsed &&
//                lhs.normalized == rhs.normalized
//        }
//    }
