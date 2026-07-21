//
//  InsightsViewModel.swift
//  Xpnse
//

import Combine
import Foundation

@MainActor
final class InsightsViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case empty
    }

    @Published private(set) var expenseTrend: ExpenseTrendChartModel = ExpenseTrendChartModel(
        points: [],
        year: Calendar.current.component(.year, from: Date()),
        projectedMonth: nil,
        hasProjection: false
    )
    @Published private(set) var snapshot: InsightsSnapshot?
    @Published private(set) var narratives: InsightsNarratives = .empty
    @Published private(set) var isGeneratingNarrative = false
    @Published private(set) var year: Int
    /// Ghost until analytics are ready; content appears all at once.
    @Published private(set) var phase: Phase = .loading

    private let transactionRepository: TransactionRepository
    private let recurringRepository: RecurringRepository
    private let calendar: Calendar
    private let narrativeService = InsightsNarrativeService()
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    private var narrativeTask: Task<Void, Never>?
    private var hasCompletedInitialLoad = false
    private var lastRevision: String?

    init(
        transactionRepository: TransactionRepository = SwiftDataTransactionRepository.shared,
        recurringRepository: RecurringRepository = SwiftDataRecurringRepository.shared,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.transactionRepository = transactionRepository
        self.recurringRepository = recurringRepository
        self.calendar = calendar
        self.year = calendar.component(.year, from: now)

        // Paint last known Insights immediately (verified against revision next).
        if let cached = InsightsResultCache.loadAny() {
            applyCached(cached, markReady: true)
        }

        transactionRepository.changesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.scheduleReload(reason: .dataChange)
            }
            .store(in: &cancellables)
    }

    var hasContent: Bool {
        !expenseTrend.points.isEmpty || (snapshot?.hasMeaningfulData ?? false)
    }

    func onAppear() {
        scheduleReload(reason: .appear)
    }

    func onDisappear() {
        narrativeTask?.cancel()
        narrativeService.cancel()
    }

    private enum ReloadReason {
        case appear
        case dataChange
    }

    private func scheduleReload(reason: ReloadReason) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.reload(reason: reason)
        }
    }

    private func reload(reason: ReloadReason) async {
        let now = Date()
        year = calendar.component(.year, from: now)

        let revision: String
        do {
            revision = try await currentRevision(now: now)
        } catch {
            revision = UUID().uuidString
        }
        guard !Task.isCancelled else { return }

        if let cached = InsightsResultCache.load(matching: revision) {
            applyCached(cached, markReady: true)
            lastRevision = revision
            return
        }

        // Same revision we already published this session — nothing to do.
        if lastRevision == revision, hasCompletedInitialLoad, hasContent {
            return
        }

        if !hasCompletedInitialLoad {
            phase = .loading
        }

        // Let the navigation push finish before heavy MainActor work.
        await Task.yield()
        await Task.yield()
        try? await Task.sleep(nanoseconds: 32_000_000)
        guard !Task.isCancelled else { return }

        // Re-check after yield in case a concurrent change landed.
        if let cached = InsightsResultCache.load(matching: revision) {
            applyCached(cached, markReady: true)
            lastRevision = revision
            return
        }

        guard let yearStart = startOfYear(year),
              let fetchStart = calendar.date(
                byAdding: .month,
                value: -(MonthExpenseExtrapolationEngine.defaultLookbackMonths + InsightsAnalyticsEngine.lookbackMonths),
                to: yearStart
              ),
              let end = endOfYear(year)
        else {
            publish(trend: emptyTrend(), snapshot: nil, narratives: .empty, revision: revision)
            return
        }

        do {
            async let transactionsTask = transactionRepository.fetch(startDate: fetchStart, endDate: end)
            async let recurringTask = recurringRepository.fetchAll()

            let transactions = try await transactionsTask
            let recurringItems = (try? await recurringTask) ?? []
            guard !Task.isCancelled else { return }

            await Task.yield()
            guard !Task.isCancelled else { return }

            let expenses = transactions.filter { $0.type == .expense }
            let builtTrend = ExpenseTrendBuilder.build(
                expenses: expenses,
                year: year,
                recurringItems: recurringItems,
                calendar: calendar,
                now: now
            )
            let builtSnapshot = InsightsAnalyticsEngine.build(
                transactions: transactions,
                recurringItems: recurringItems,
                focusDate: now,
                calendar: calendar
            )

            guard !Task.isCancelled else { return }
            publish(trend: builtTrend, snapshot: builtSnapshot, narratives: .empty, revision: revision)
            scheduleNarratives(for: builtSnapshot, revision: revision)
        } catch {
            guard !Task.isCancelled else { return }
            if reason == .appear || !hasContent {
                publish(trend: emptyTrend(), snapshot: nil, narratives: .empty, revision: revision)
            }
        }
    }

    private func currentRevision(now: Date) async throws -> String {
        async let txUpdated = transactionRepository.updatedAtById()
        async let recurringUpdated = recurringRepository.updatedAtById()
        return InsightsResultCache.revision(
            transactionUpdatedAtById: try await txUpdated,
            recurringUpdatedAtById: try await recurringUpdated,
            focusDay: now,
            currencyCode: CurrencyManager.shared.selectedCurrency.code,
            calendar: calendar
        )
    }

    private func applyCached(_ cached: InsightsCachedResult, markReady: Bool) {
        expenseTrend = cached.expenseTrend
        snapshot = cached.snapshot
        narratives = cached.narratives
        year = cached.year
        isGeneratingNarrative = false
        hasCompletedInitialLoad = true
        lastRevision = cached.revision
        if markReady {
            let ready = !cached.expenseTrend.points.isEmpty || cached.snapshot.hasMeaningfulData
            phase = ready ? .ready : .empty
        }
    }

    private func publish(
        trend: ExpenseTrendChartModel,
        snapshot: InsightsSnapshot?,
        narratives: InsightsNarratives,
        revision: String
    ) {
        expenseTrend = trend
        self.snapshot = snapshot
        self.narratives = narratives
        hasCompletedInitialLoad = true
        lastRevision = revision

        let ready = !trend.points.isEmpty || (snapshot?.hasMeaningfulData ?? false)
        phase = ready ? .ready : .empty
        if !ready {
            self.narratives = .empty
            isGeneratingNarrative = false
            return
        }

        if let snapshot {
            InsightsResultCache.save(
                InsightsCachedResult(
                    revision: revision,
                    generatedAt: Date(),
                    year: year,
                    expenseTrend: trend,
                    snapshot: snapshot,
                    narratives: narratives
                )
            )
        }
    }

    private func scheduleNarratives(for snapshot: InsightsSnapshot, revision: String) {
        narrativeTask?.cancel()
        guard snapshot.hasMeaningfulData else {
            narratives = .empty
            isGeneratingNarrative = false
            return
        }

        isGeneratingNarrative = true
        narrativeTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.narrativeService.narratives(for: snapshot)
            guard !Task.isCancelled else { return }
            self.narratives = result
            self.isGeneratingNarrative = false

            // Persist narratives into the same revision cache entry.
            if let snap = self.snapshot, self.lastRevision == revision {
                InsightsResultCache.save(
                    InsightsCachedResult(
                        revision: revision,
                        generatedAt: Date(),
                        year: self.year,
                        expenseTrend: self.expenseTrend,
                        snapshot: snap,
                        narratives: result
                    )
                )
            }
        }
    }

    private func emptyTrend() -> ExpenseTrendChartModel {
        ExpenseTrendChartModel(
            points: [],
            year: year,
            projectedMonth: nil,
            hasProjection: false
        )
    }

    private func startOfYear(_ year: Int) -> Date? {
        calendar.date(from: DateComponents(year: year, month: 1, day: 1))
    }

    private func endOfYear(_ year: Int) -> Date? {
        guard let startOfNext = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return nil }
        return startOfNext.addingTimeInterval(-1)
    }
}
