//
//  InsightsView.swift
//  Xpnse
//

import SwiftUI

struct InsightsView: View {
    var body: some View {
        ZStack {
            PrimaryGradient()

            Text("Insights coming soon")
                .font(.headline)
                .xpnseAdaptiveForeground(muted: true)
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}
