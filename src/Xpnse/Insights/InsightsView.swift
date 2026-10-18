//
//  InsightsView.swift
//  Xpnse
//

import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @State private var createRecurringSuggestion: InsightsPotentialRecurring?
    @State private var loggedViewStates: Set<AppAnalytics.FeatureState> = []

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
        .onChange(of: viewModel.phase, initial: true) { _, _ in
            logViewedIfResolved()
        }
        .onChange(of: viewModel.didFailToLoad) { _, _ in
            logViewedIfResolved()
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

    /// Once per distinct rendered state per visit; redraws and refreshes into the same state are ignored.
    private func logViewedIfResolved() {
        guard let state = Self.viewedState(phase: viewModel.phase, didFailToLoad: viewModel.didFailToLoad),
              loggedViewStates.insert(state).inserted else { return }
        var parameters = [AppAnalytics.Param.state: state.rawValue]
        if state == .error {
            parameters[AppAnalytics.Param.failureReason] = AppAnalytics.FailureReason.persistence.rawValue
        }
        AppAnalytics.logEvent(AppAnalytics.Event.insightsViewed, parameters: parameters)
    }

    /// A failed refresh that keeps earlier content on screen is still `ready`; the failure is what the
    /// user sees only when the fallback empty state replaces it.
    static func viewedState(phase: InsightsViewModel.Phase, didFailToLoad: Bool) -> AppAnalytics.FeatureState? {
        switch phase {
        case .loading: return nil
        case .ready: return .ready
        case .empty: return didFailToLoad ? .error : .empty
        }
    }

    private func logInsightAction(_ actionType: String) {
        AppAnalytics.logEvent(AppAnalytics.Event.insightActionSelected, parameters: [
            AppAnalytics.Param.actionType: actionType
        ])
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
                            onMakeRecurring: {
                                logInsightAction("make_recurring")
                                createRecurringSuggestion = $0
                            },
                            onMarkNotRecurring: {
                                logInsightAction("not_recurring")
                                viewModel.dismissPotentialRecurring($0)
                            }
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
