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
                switch viewModel.phase {
                case .loading:
                    InsightsGhostView()
                        .transition(.opacity)
                case .empty:
                    emptyState
                        .transition(.opacity)
                case .ready:
                    insightsContent
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.phase)
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Prefer `.task` so work is tied to view lifetime and starts after the first layout.
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    private var insightsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !viewModel.expenseTrend.points.isEmpty {
                    ExpenseTrendChart(model: viewModel.expenseTrend)
                }

                if let snapshot = viewModel.snapshot, snapshot.hasMeaningfulData {
                    InsightHealthCard(
                        score: snapshot.healthScore,
                        savingsRate: snapshot.savingsRate,
                        summary: viewModel.narratives.healthSummary,
                        personalityLabel: viewModel.narratives.personalityLabel,
                        personalityBlurb: viewModel.narratives.personalityBlurb
                    )

                    InsightBiggestChangesCard(
                        changes: snapshot.biggestChanges,
                        currencySymbol: snapshot.currencySymbol
                    )

                    InsightTopMerchantsCard(
                        merchants: snapshot.topMerchants,
                        currencySymbol: snapshot.currencySymbol,
                        gloss: viewModel.narratives.merchantGloss
                    )

                    InsightCategoryHealthCard(
                        baselines: snapshot.categoryBaselines,
                        currencySymbol: snapshot.currencySymbol
                    )

                    InsightForecastCard(
                        forecast: snapshot.forecast,
                        currencySymbol: snapshot.currencySymbol
                    )

                    if !snapshot.events.isEmpty {
                        InsightEventsCard(
                            events: snapshot.events,
                            currencySymbol: snapshot.currencySymbol
                        )
                    }

                    InsightOpportunitiesCard(
                        opportunities: viewModel.narratives.opportunities,
                        wins: viewModel.narratives.wins,
                        isLoading: viewModel.isGeneratingNarrative
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 36, weight: .medium))
                .xpnseAdaptiveForeground(muted: true)

            Text("No insights yet")
                .font(.headline)
                .xpnseAdaptiveForeground()

            Text("Add income and expense transactions to see trends, forecasts, and AI coaching.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .xpnseAdaptiveForeground(muted: true)
                .padding(.horizontal, 32)
        }
    }
}
