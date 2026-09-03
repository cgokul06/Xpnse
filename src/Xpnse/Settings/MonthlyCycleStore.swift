//
//  MonthlyCycleStore.swift
//  Xpnse
//

import Combine
import Foundation

@MainActor
final class MonthlyCycleStore: ObservableObject {
    static let shared = MonthlyCycleStore()

    @Published private(set) var configuration: MonthlyCycleConfiguration

    private init() {
        configuration = MonthlyCyclePreference.current
    }

    var resolver: MonthlyCycleResolver {
        MonthlyCycleResolver(configuration: configuration, calendar: .current)
    }

    func setStartDay(_ day: Int) {
        let next = MonthlyCycleConfiguration.fixedStartDay(day)
        guard next != configuration else { return }
        MonthlyCyclePreference.setStartDay(next.startDay)
        configuration = next
        Task { await WidgetRefreshCoordinator.shared.refresh() }
    }
}
