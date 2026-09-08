//
//  EducationTracking.swift
//  Xpnse
//

import Foundation

/// App-level helper: refresh live context, then notify the engine and presentation layer.
enum EducationTracking {
    static var isRunningInTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    @MainActor
    static func track(_ event: EducationEvent) async {
        await AppEducationEvaluationContextProvider.shared.refresh()
        EducationEngine.shared.track(event)
        EducationPresentationCoordinator.shared.completeJourneysIfNeeded(for: event)
        EducationPresentationCoordinator.shared.tryPresent()
    }
}
