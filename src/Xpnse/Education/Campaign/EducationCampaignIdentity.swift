//
//  EducationCampaignIdentity.swift
//  Xpnse
//

import Foundation

/// Stable metadata for an education campaign. `id` must not change across app versions.
struct EducationCampaignIdentity: Equatable, Hashable, Sendable {
    let id: String
    let name: String
    /// Lower value = higher precedence when multiple campaigns qualify.
    let priority: Int

    init(id: String, name: String, priority: Int) {
        self.id = id
        self.name = name
        self.priority = priority
    }
}
