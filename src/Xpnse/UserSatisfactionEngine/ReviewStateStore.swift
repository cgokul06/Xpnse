//
//  ReviewStateStore.swift
//  Xpnse
//

import Foundation

protocol ReviewStateStore {
    func load() -> ReviewState?
    func save(_ state: ReviewState)
}

final class UserDefaultsReviewStateStore: ReviewStateStore {
    private let helper: UserDefaultsHelper
    private let key: UserDefaultsKey

    init(helper: UserDefaultsHelper = .shared, key: UserDefaultsKey = .reviewState) {
        self.helper = helper
        self.key = key
    }

    func load() -> ReviewState? {
        guard let data = helper.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ReviewState.self, from: data)
    }

    func save(_ state: ReviewState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        helper.setData(data, forKey: key)
    }
}

final class InMemoryReviewStateStore: ReviewStateStore {
    private var state: ReviewState?

    init(state: ReviewState? = nil) {
        self.state = state
    }

    func load() -> ReviewState? { state }

    func save(_ state: ReviewState) {
        self.state = state
    }
}
