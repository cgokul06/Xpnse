//
//  InsightsView.swift
//  Xpnse
//

import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @State private var createRecurringSuggestion: InsightsPotentialRecurring?

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
            AppAnalytics.logScreen(AppAnalytics.Screen.insights)
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .sheet(item: $createRecurringSuggestion) { suggestion in
            EditRecurringTransactionView(suggestion: suggestion) {
                viewModel.onAppear()
            }
        }
    }

    private var insightsContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 16) {
                if !viewModel.expenseTrend.points.isEmpty {
                    ExpenseTrendChart(model: viewModel.expenseTrend)
                }

                if let snapshot = viewModel.snapshot, snapshot.hasMeaningfulData {
                    InsightHealthCard(
                        totalScore: snapshot.healthBreakdown.totalScore,
                        savingsRate: snapshot.forecast.expectedIncome > 0
                            ? snapshot.forecast.expectedSavings / snapshot.forecast.expectedIncome
                            : snapshot.savingsRate,
                        summary: viewModel.narratives.healthSummary,
                        personalityLabel: viewModel.narratives.personalityLabel,
                        personalityBlurb: viewModel.narratives.personalityBlurb
                    )

                    if !snapshot.biggestChanges.isEmpty {
                        InsightBiggestChangesCard(
                            changes: snapshot.biggestChanges,
                            currencyCode: CurrencyManager.shared.selectedCurrency.code
                        )
                    }

                    InsightTopMerchantsCard(
                        merchants: snapshot.topMerchants,
                        currencyCode: CurrencyManager.shared.selectedCurrency.code,
                        gloss: viewModel.narratives.merchantGloss
                    )

                    if !snapshot.categoryBaselines.isEmpty {
                        InsightCategoryHealthCard(
                            baselines: snapshot.categoryBaselines,
                            currencyCode: CurrencyManager.shared.selectedCurrency.code
                        )
                    }

                    InsightForecastCard(
                        forecast: snapshot.forecast,
                        currencyCode: CurrencyManager.shared.selectedCurrency.code
                    )

                    if !snapshot.events.isEmpty {
                        InsightEventsCard(
                            events: snapshot.events,
                            currencyCode: CurrencyManager.shared.selectedCurrency.code
                        )
                    }

                    if !snapshot.potentialRecurring.isEmpty {
                        InsightPotentialRecurringCard(
                            items: snapshot.potentialRecurring,
                            currencyCode: CurrencyManager.shared.selectedCurrency.code,
                            onMakeRecurring: { createRecurringSuggestion = $0 },
                            onMarkNotRecurring: { viewModel.dismissPotentialRecurring($0) }
                        )
                    }

                    InsightOpportunitiesCard(
                        opportunities: viewModel.narratives.opportunities,
                        wins: viewModel.narratives.wins,
                        isLoading: viewModel.isGeneratingNarrative
                    )
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollClipDisabled(false)
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
