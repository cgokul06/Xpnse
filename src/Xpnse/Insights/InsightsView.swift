//
//  InsightsView.swift
//  Xpnse
//

import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()

    var body: some View {
        ZStack {
            PrimaryGradient()

            Group {
                if viewModel.isLoading && viewModel.expenseTrend.points.isEmpty {
                    ProgressView()
                } else if viewModel.expenseTrend.points.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ExpenseTrendChart(model: viewModel.expenseTrend)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onAppear()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 36, weight: .medium))
                .xpnseAdaptiveForeground(muted: true)

            Text("No expenses this year")
                .font(.headline)
                .xpnseAdaptiveForeground()

            Text("Add expense transactions to see your cumulative daily trend.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .xpnseAdaptiveForeground(muted: true)
                .padding(.horizontal, 32)
        }
    }
}
