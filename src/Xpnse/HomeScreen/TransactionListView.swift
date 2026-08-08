//
//  TransactionListView.swift
//  Xpnse
//
//  Created by Gokul C on 22/10/25.
//

import SwiftUI
import UIKit

enum TransactionListPersistedAnchor: Hashable {
    case top
    /// First real (materialized) section — used to tuck upcoming above the fold on open.
    case firstMaterialized
    case date(Date)
    case category(String)
}

enum TransactionListGrouping {
    case date
    case category
}

struct TransactionListScrollUpdate: Equatable {
    let offsetY: CGFloat
    let previousOffsetY: CGFloat
    let delta: CGFloat
    let visibleHeight: CGFloat
    let contentHeight: CGFloat

    var maxOffset: CGFloat {
        max(0, contentHeight - visibleHeight)
    }
}

private struct TransactionListScrollMetrics: Equatable {
    let offsetY: CGFloat
    let visibleHeight: CGFloat
    let contentHeight: CGFloat

    var isScrollable: Bool {
        guard visibleHeight > 0 else { return false }
        return contentHeight > visibleHeight + 1
    }

    static func from(_ geometry: ScrollGeometry) -> TransactionListScrollMetrics {
        TransactionListScrollMetrics(
            offsetY: max(0, geometry.contentOffset.y).rounded(.down),
            visibleHeight: geometry.visibleRect.height.rounded(.down),
            contentHeight: geometry.contentSize.height.rounded(.down)
        )
    }
}

private struct CategorySection: Identifiable {
    let id: String
    let category: CategoryDefinition
    let transactions: [Transaction]
}

private struct TransactionsHeaderMinYKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

private struct TransactionsHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private enum StickySectionID: Hashable {
    case date(Date)
    case category(String)
}

private struct StickySectionFrame: Equatable {
    let id: StickySectionID
    let minY: CGFloat
}

private struct SectionHeaderFramesKey: PreferenceKey {
    static var defaultValue: [StickySectionFrame] = []

    static func reduce(value: inout [StickySectionFrame], nextValue: () -> [StickySectionFrame]) {
        value.append(contentsOf: nextValue())
    }
}

struct TransactionListView: View {
    let monthKey: Int
    var summary: TransactionSummary?
    @Binding var isShowingDonut: Bool
    var dateTransactions: [Date: [Transaction]]
    @Binding var grouping: TransactionListGrouping
    @Binding var showUpcomingRecurring: Bool
    @Binding var typeFilter: TransactionListTypeFilter
    @Binding var sortOrder: TransactionListSortOrder
    var savedScrollAnchor: TransactionListPersistedAnchor?
    var onScrollAnchorChange: (TransactionListPersistedAnchor) -> Void
    var onScrollOffsetChange: ((TransactionListScrollUpdate) -> Void)?
    var onListAppear: (() -> Void)?
    /// Increment from the parent to programmatically scroll back to the balance card.
    var scrollToTopTick: UInt = 0
    @Binding var isSearching: Bool
    var scrollBottomInset: CGFloat = 62
    var extendsToBottomSafeArea: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var categoryStore = CategoryStore.shared
    @State private var scrollMetrics = TransactionListScrollMetrics(
        offsetY: 0,
        visibleHeight: 0,
        contentHeight: 0
    )
    @State private var scrollAnchor: TransactionListPersistedAnchor? = .top
    @State private var needsScrollRestore = false
    @State private var lastKnownTopDate: Date?
    @State private var lastTransactionCount = 0
    @State private var pendingScrollMetrics: TransactionListScrollMetrics?
    @State private var isTransactionsHeaderPinned = false
    @State private var transactionsHeaderHeight: CGFloat = 52
    @State private var sectionHeaderFrames: [StickySectionFrame] = []
    @State private var stickySectionID: StickySectionID?
    @State private var pendingProgrammaticScroll: TransactionListPersistedAnchor?
    @State private var searchText = ""
    @State private var debouncedSearchQuery = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var upcomingItems: [UpcomingRecurringItem] = []
    @State private var selectedRecurringForEdit: RecurringTransaction?

    private static let summaryCardScrollThreshold: CGFloat = SummaryCardMetrics.height + 12
    private static let searchDebounceInterval: Duration = .milliseconds(300)
    private let calendar = Calendar.current
    private let transactionManager = FirebaseTransactionManager.shared

    private var scrollContentBottomPadding: CGFloat {
        let safeAreaPadding = extendsToBottomSafeArea ? DeviceSafeArea.bottom : 0
        return scrollBottomInset + safeAreaPadding
    }

    private var filteredDateTransactions: [Date: [Transaction]] {
        var result: [Date: [Transaction]] = [:]
        for (date, transactions) in dateTransactions {
            let filtered = transactions.filter { typeFilter.includes($0.type) }
            if !filtered.isEmpty {
                result[date] = filtered
            }
        }
        return result
    }

    private var dates: [Date] {
        sortOrder.datesSorted(Array(filteredDateTransactions.keys))
    }

    private var sortedUpcomingItems: [UpcomingRecurringItem] {
        sortOrder.upcomingSorted(
            upcomingItems.filter { typeFilter.includes($0.transactionType) }
        )
    }

    private var upcomingDateGroups: [(date: Date, items: [UpcomingRecurringItem])] {
        Dictionary(grouping: sortedUpcomingItems) { calendar.startOfDay(for: $0.occurrenceDate) }
            .map { (date: $0.key, items: sortOrder.upcomingSorted($0.value)) }
            .sorted { lhs, rhs in
                switch sortOrder {
                case .descending: return lhs.date > rhs.date
                case .ascending: return lhs.date < rhs.date
                }
            }
    }

    /// Upcoming belongs in the transaction list (below the header), not above the balance card.
    private var showsUpcomingInList: Bool {
        !sortedUpcomingItems.isEmpty && !isSearchActive
    }

    private var firstMaterializedAnchor: TransactionListPersistedAnchor? {
        guard hasTransactions else { return nil }
        switch grouping {
        case .date:
            guard let date = dates.first else { return nil }
            return .date(date)
        case .category:
            guard let section = categorySections.first else { return nil }
            return .category(section.id)
        }
    }

    /// On open, skip past upcoming so only real transactions are in view.
    private var preferredListEntryAnchor: TransactionListPersistedAnchor {
        if showsUpcomingInList, firstMaterializedAnchor != nil {
            return .firstMaterialized
        }
        return .top
    }

    private var allTransactions: [Transaction] {
        dates.flatMap { filteredDateTransactions[$0] ?? [] }
    }

    private var isSearchActive: Bool {
        !debouncedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredSearchResults: [Transaction] {
        let query = debouncedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        return sortOrder.transactionsSorted(
            allTransactions.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || ($0.merchant?.localizedCaseInsensitiveContains(query) ?? false)
            }
        )
    }

    private var categorySections: [CategorySection] {
        let grouped = Dictionary(grouping: allTransactions) { transaction in
            categoryStore.canonicalCategoryId(for: transaction.categoryId)
        }
        return grouped
            .map { categoryId, transactions in
                CategorySection(
                    id: categoryId,
                    category: categoryStore.resolve(id: categoryId),
                    transactions: sortOrder.transactionsSorted(transactions)
                )
            }
            .sorted { lhs, rhs in
                let lhsSpend = expenseTotal(for: lhs.transactions)
                let rhsSpend = expenseTotal(for: rhs.transactions)
                if lhsSpend != rhsSpend {
                    return lhsSpend > rhsSpend
                }
                let lhsIncome = incomeTotal(for: lhs.transactions)
                let rhsIncome = incomeTotal(for: rhs.transactions)
                if lhsIncome != rhsIncome {
                    return lhsIncome > rhsIncome
                }
                return lhs.category.name.localizedCaseInsensitiveCompare(rhs.category.name) == .orderedAscending
            }
    }

    private func expenseTotal(for transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.totalAmount }
    }

    private func savingsTotal(for transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.type == .savings }
            .reduce(0) { $0 + $1.totalAmount }
    }

    private func incomeTotal(for transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.totalAmount }
    }

    private func netTotal(for transactions: [Transaction]) -> Double {
        incomeTotal(for: transactions) - expenseTotal(for: transactions) - savingsTotal(for: transactions)
    }

    @ViewBuilder
    private func sectionNetTotalLabel(for transactions: [Transaction]) -> some View {
        let net = netTotal(for: transactions)
        let currency = transactions.first?.currency ?? CurrencyManager.shared.selectedCurrency
        let isNegative = net < 0
        let displayAmount = abs(net)

        Text(AmountFormatter.format(displayAmount, currencyCode: currency.code))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(
                isNegative
                    ? TransactionType.expense.brandColor
                    : TransactionType.income.brandColor
            )
    }

    private var hasTransactions: Bool {
        !allTransactions.isEmpty
    }

    /// Keep list chrome (options) when the month has data that filters may temporarily hide.
    private var hasListContent: Bool {
        !dateTransactions.isEmpty || !upcomingItems.isEmpty || hasTransactions
    }

    private var isPartiallyScrolled: Bool {
        guard scrollMetrics.isScrollable else { return false }
        guard scrollMetrics.visibleHeight > 0 else {
            return scrollMetrics.offsetY > 24
        }
        return scrollMetrics.offsetY > scrollMetrics.visibleHeight * 0.5
    }

    var body: some View {
        Group {
            if hasListContent || isSearching {
                transactionScrollContent
            } else {
                noTransactionsFound
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onChange(of: dateTransactions) { _, _ in
            handleTransactionDataChange()
            Task { await reloadUpcomingIfNeeded() }
        }
        .onChange(of: grouping) { _, _ in
            stickySectionID = nil
            sectionHeaderFrames = []
            let entry = preferredListEntryAnchor
            scrollAnchor = entry
            onScrollAnchorChange(entry)
            pendingProgrammaticScroll = entry
        }
        .onChange(of: searchText) { _, newValue in
            scheduleSearchDebounce(for: newValue)
        }
        .onChange(of: debouncedSearchQuery) { _, _ in
            stickySectionID = nil
            pendingProgrammaticScroll = .top
        }
        .onChange(of: monthKey) { _, _ in
            closeSearch()
            Task { await reloadUpcomingIfNeeded() }
        }
        .onChange(of: showUpcomingRecurring) { _, _ in
            Task { await reloadUpcomingIfNeeded() }
        }
        .onChange(of: typeFilter) { _, _ in
            stickySectionID = nil
            sectionHeaderFrames = []
            let entry = preferredListEntryAnchor
            scrollAnchor = entry
            onScrollAnchorChange(entry)
            pendingProgrammaticScroll = entry
        }
        .onChange(of: sortOrder) { _, _ in
            stickySectionID = nil
            sectionHeaderFrames = []
            let entry = preferredListEntryAnchor
            scrollAnchor = entry
            onScrollAnchorChange(entry)
            pendingProgrammaticScroll = entry
        }
        .onChange(of: isSearching) { _, isActive in
            if !isActive {
                clearSearchInput()
            }
        }
        .dismissKeyboardOnOutsideTap(isEnabled: isSearching) {
            handleSearchDismissInteraction()
        }
        .sheet(item: $selectedRecurringForEdit) { item in
            EditRecurringTransactionView(item: item) {
                Task { await reloadUpcomingIfNeeded() }
            }
        }
        .task {
            await categoryStore.load()
            await reloadUpcomingIfNeeded()
        }
    }

    private func reloadUpcomingIfNeeded() async {
        guard showUpcomingRecurring else {
            await MainActor.run { upcomingItems = [] }
            return
        }

        let comparison = CalendarComparison(
            rawValue: UserDefaultsHelper.shared.integer(forKey: .calendarAggregator)
        ) ?? .monthly
        let range = PeriodDateRangeCalculator.dateRange(
            forOffset: monthKey,
            comparison: comparison,
            calendar: calendar
        )
        let startOfToday = calendar.startOfDay(for: Date())
        guard range.end >= startOfToday else {
            await MainActor.run { upcomingItems = [] }
            return
        }

        let rules = await transactionManager.fetchRecurringTransactions()
        let materializedKeys = await transactionManager.materializedRecurringOccurrenceKeys(
            startDate: max(range.start, startOfToday),
            endDate: range.end
        )
        let projected = UpcomingRecurringProjector.project(
            rules: rules,
            periodStart: range.start,
            periodEnd: range.end,
            calendar: calendar,
            materializedKeys: materializedKeys
        )

        await MainActor.run {
            upcomingItems = projected
        }
    }

    private func scheduleSearchDebounce(for text: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(for: Self.searchDebounceInterval)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                debouncedSearchQuery = text
            }
        }
    }

    private func activateSearch() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.25)) {
            isSearching = true
        }
        DispatchQueue.main.async {
            isSearchFieldFocused = true
        }
    }

    private func closeSearch() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isSearching = false
        }
        clearSearchInput()
    }

    private func clearSearchInput() {
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
        searchText = ""
        debouncedSearchQuery = ""
        isSearchFieldFocused = false
    }

    private func resignSearchKeyboard() {
        guard isSearchFieldFocused else {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
            return
        }
        isSearchFieldFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    /// Outside tap / scroll: keep an active query, otherwise close the search bar.
    private func handleSearchDismissInteraction() {
        guard isSearching else { return }
        resignSearchKeyboard()
        if hasSearchQuery { return }
        closeSearch()
    }

    private func handleScrollGeometryChange(
        from oldMetrics: TransactionListScrollMetrics,
        to newMetrics: TransactionListScrollMetrics
    ) {
        guard newMetrics != scrollMetrics else { return }

        let scrollabilityChanged = oldMetrics.isScrollable != newMetrics.isScrollable
        let needsInitialLayout = scrollMetrics.visibleHeight == 0 && newMetrics.visibleHeight > 0

        guard scrollabilityChanged || needsInitialLayout || newMetrics.isScrollable else {
            return
        }

        pendingScrollMetrics = newMetrics
        DispatchQueue.main.async {
            applyPendingScrollMetricsIfNeeded()
        }
    }

    private func applyPendingScrollMetricsIfNeeded() {
        guard let newMetrics = pendingScrollMetrics else { return }
        pendingScrollMetrics = nil
        guard newMetrics != scrollMetrics else { return }

        let previousOffsetY = scrollMetrics.offsetY
        let wasScrollable = scrollMetrics.isScrollable
        scrollMetrics = newMetrics

        if isSearching, abs(newMetrics.offsetY - previousOffsetY) > 0 {
            handleSearchDismissInteraction()
        }

        if newMetrics.isScrollable {
            onScrollOffsetChange?(
                TransactionListScrollUpdate(
                    offsetY: newMetrics.offsetY,
                    previousOffsetY: previousOffsetY,
                    delta: newMetrics.offsetY - previousOffsetY,
                    visibleHeight: newMetrics.visibleHeight,
                    contentHeight: newMetrics.contentHeight
                )
            )
        } else if wasScrollable || newMetrics.offsetY > 0.5 {
            // Short months: hiding the bottom bar can shrink overflow below zero while
            // offsetY is still mid-list. Bounce is disabled, so force recovery.
            pendingProgrammaticScroll = .top
            onScrollOffsetChange?(
                TransactionListScrollUpdate(
                    offsetY: 0,
                    previousOffsetY: previousOffsetY,
                    delta: -previousOffsetY,
                    visibleHeight: newMetrics.visibleHeight,
                    contentHeight: newMetrics.contentHeight
                )
            )
        }

        if !newMetrics.isScrollable, scrollAnchor != .top {
            scrollAnchor = .top
        }

        updateVisibleScrollAnchor(from: newMetrics)
    }

    private func updateVisibleScrollAnchor(from metrics: TransactionListScrollMetrics) {
        guard metrics.isScrollable else { return }

        if metrics.offsetY < Self.summaryCardScrollThreshold {
            guard scrollAnchor != .top else { return }
            scrollAnchor = .top
            onScrollAnchorChange(.top)
        }
    }

    private func syncTransactionSnapshot() {
        lastKnownTopDate = dates.first
        lastTransactionCount = allTransactions.count
    }

    private func handleTransactionDataChange() {
        let newTopDate = dates.first
        let newCount = allTransactions.count

        if isScrollAnchorStale {
            revealNewestContent(topDate: newTopDate)
        } else if lastTransactionCount > 0, newCount > lastTransactionCount {
            if scrollAnchor != .top, newTopDate != lastKnownTopDate {
                revealNewestContent(topDate: newTopDate)
            }
        } else if lastTransactionCount == 0, newCount > 0, !needsScrollRestore {
            revealNewestContent(topDate: newTopDate)
        } else if needsScrollRestore {
            pendingProgrammaticScroll = validatedScrollAnchor(savedScrollAnchor)
        }

        lastKnownTopDate = newTopDate
        lastTransactionCount = newCount
    }

    private var isScrollAnchorStale: Bool {
        guard let scrollAnchor else { return true }

        switch scrollAnchor {
        case .top:
            return false
        case .firstMaterialized:
            return firstMaterializedAnchor == nil
        case .date(let date):
            return grouping == .date && !dates.contains(date)
        case .category(let categoryId):
            return grouping == .category
                && !categorySections.contains(where: { $0.id == categoryId })
        }
    }

    private func revealNewestContent(topDate: Date?) {
        let target: TransactionListPersistedAnchor
        if scrollMetrics.isScrollable, showsUpcomingInList, firstMaterializedAnchor != nil {
            target = .firstMaterialized
        } else if scrollMetrics.isScrollable, grouping == .date, let topDate {
            target = .date(topDate)
        } else {
            target = .top
        }

        DispatchQueue.main.async {
            self.pendingProgrammaticScroll = target
        }
    }

    private func scrollToAnchor(_ anchor: TransactionListPersistedAnchor, proxy: ScrollViewProxy) {
        let scrollTarget: TransactionListPersistedAnchor
        if !scrollMetrics.isScrollable {
            scrollTarget = .top
        } else if case .firstMaterialized = anchor {
            scrollTarget = firstMaterializedAnchor ?? .top
        } else {
            scrollTarget = anchor
        }

        let persisted: TransactionListPersistedAnchor = {
            if case .firstMaterialized = anchor, firstMaterializedAnchor != nil {
                return .firstMaterialized
            }
            return scrollTarget
        }()

        scrollAnchor = persisted
        onScrollAnchorChange(persisted)

        var transaction = SwiftUI.Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(scrollTarget, anchor: .top)
        }
    }

    private func scheduleScrollRestore(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                applyValidatedSavedAnchor(using: proxy)
            }
        }
    }

    private func applyValidatedSavedAnchor(using proxy: ScrollViewProxy) {
        guard needsScrollRestore else { return }

        if !hasListContent {
            needsScrollRestore = false
            return
        }

        if scrollMetrics.visibleHeight == 0 {
            scheduleScrollRestore(using: proxy)
            return
        }

        if !scrollMetrics.isScrollable {
            needsScrollRestore = false
            return
        }

        needsScrollRestore = false
        let target = validatedScrollAnchor(savedScrollAnchor)
        scrollToAnchor(target, proxy: proxy)
    }

    private func validatedScrollAnchor(
        _ anchor: TransactionListPersistedAnchor?
    ) -> TransactionListPersistedAnchor {
        guard let anchor else { return preferredListEntryAnchor }

        switch anchor {
        case .top:
            // Default / restored top with upcoming → land on real transactions.
            return preferredListEntryAnchor
        case .firstMaterialized:
            return firstMaterializedAnchor != nil ? .firstMaterialized : .top
        case .date(let date):
            guard grouping == .date, dates.contains(date) else { return preferredListEntryAnchor }
            return anchor
        case .category(let categoryId):
            guard grouping == .category,
                  categorySections.contains(where: { $0.id == categoryId })
            else { return preferredListEntryAnchor }
            return anchor
        }
    }

    private func resetScrollIfNeeded(
        from oldPhase: ScenePhase,
        to newPhase: ScenePhase,
        proxy: ScrollViewProxy
    ) {
        guard isPartiallyScrolled else { return }

        switch newPhase {
        case .background, .inactive:
            scrollToTop(using: proxy)
        case .active where oldPhase == .background || oldPhase == .inactive:
            scrollToTop(using: proxy)
        default:
            break
        }
    }

    private func scrollToTop(using proxy: ScrollViewProxy) {
        scrollToAnchor(.top, proxy: proxy)
    }

    private var transactionScrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    if summary != nil {
                        FlippableSummaryCardView(
                            summary: summary,
                            isShowingDonut: $isShowingDonut
                        )
                        .id(TransactionListPersistedAnchor.top)
                    }

                    transactionsSectionHeader
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: TransactionsHeaderMinYKey.self,
                                    value: geometry.frame(in: .named("transactionScroll")).minY
                                )
                            }
                        )

                    if showsUpcomingInList {
                        upcomingSection(subtitle: grouping == .date ? .category : .date)
                    }

                    switch grouping {
                    case .date:
                        if isSearchActive {
                            searchResultsContent
                        } else {
                            ForEach(dates, id: \.self) { date in
                                dateSection(
                                    date: date,
                                    transactions: sortOrder.transactionsSorted(
                                        filteredDateTransactions[date] ?? []
                                    )
                                )
                                    .id(TransactionListPersistedAnchor.date(date))
                            }
                        }
                    case .category:
                        if isSearchActive {
                            searchResultsContent
                        } else {
                            ForEach(categorySections) { section in
                                categorySection(section)
                                    .id(TransactionListPersistedAnchor.category(section.id))
                            }
                        }
                    }
                }
                .padding(.bottom, scrollContentBottomPadding)
            }
            .coordinateSpace(name: "transactionScroll")
            .disableBounces()
            .onPreferenceChange(TransactionsHeaderMinYKey.self) { minY in
                isTransactionsHeaderPinned = minY < 0
                refreshStickySectionHeader()
            }
            .onPreferenceChange(TransactionsHeaderHeightKey.self) { height in
                guard height > 0 else { return }
                transactionsHeaderHeight = height
                refreshStickySectionHeader()
            }
            .onPreferenceChange(SectionHeaderFramesKey.self) { frames in
                sectionHeaderFrames = frames
                refreshStickySectionHeader()
            }
            .overlay(alignment: .top) {
                stickyHeadersOverlay
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollDismissesKeyboard(.immediately)
            .ignoresSafeArea(.container, edges: extendsToBottomSafeArea ? .bottom : [])
            .onScrollGeometryChange(for: TransactionListScrollMetrics.self) { geometry in
                TransactionListScrollMetrics.from(geometry)
            } action: { oldMetrics, newMetrics in
                handleScrollGeometryChange(from: oldMetrics, to: newMetrics)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                resetScrollIfNeeded(from: oldPhase, to: newPhase, proxy: proxy)
            }
            .onChange(of: pendingProgrammaticScroll) { _, target in
                guard let target else { return }
                pendingProgrammaticScroll = nil
                scrollToAnchor(target, proxy: proxy)
            }
            .onChange(of: scrollToTopTick) { oldValue, newValue in
                guard newValue != oldValue else { return }
                scrollToTop(using: proxy)
            }
            .onChange(of: upcomingItems.count) { oldCount, newCount in
                // When upcoming appears at the top of the list, keep real transactions in view.
                guard newCount > oldCount, showsUpcomingInList, firstMaterializedAnchor != nil else { return }
                let shouldTuck = scrollAnchor == .top
                    || scrollAnchor == .firstMaterialized
                    || scrollMetrics.offsetY < Self.summaryCardScrollThreshold
                guard shouldTuck else { return }
                pendingProgrammaticScroll = .firstMaterialized
            }
            .onAppear {
                onListAppear?()
                syncTransactionSnapshot()
                needsScrollRestore = true
                scheduleScrollRestore(using: proxy)
            }
        }
    }

    private var transactionsSectionHeader: some View {
        HStack(spacing: 8) {
            if isSearching {
                searchField
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                Text("home.transactions")
                    .font(.system(size: 18, weight: .medium))
                    .xpnseAdaptiveForeground()

                listOptionsButton

                Spacer(minLength: 0)

                Button {
                    AppAnalytics.logButtonClick(AppAnalytics.Button.searchTransactions, source: AppAnalytics.Screen.home)
                    activateSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                        .frame(width: 36, height: 36)
                        .background(AdaptiveBrandSurface.rowBackground(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel(L10n.tr("home.search_transactions"))
                .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AdaptiveBrandSurface.background(for: colorScheme))
        .animation(.easeInOut(duration: 0.25), value: isSearching)
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: TransactionsHeaderHeightKey.self,
                    value: geometry.size.height
                )
            }
        )
    }

    @ViewBuilder
    private var stickyHeadersOverlay: some View {
        VStack(spacing: 0) {
            if isTransactionsHeaderPinned {
                transactionsSectionHeader
            }
            if !isSearchActive, let stickySectionID {
                stickySectionHeader(for: stickySectionID)
            }
        }
    }

    private var sectionHeaderPinY: CGFloat {
        isTransactionsHeaderPinned ? transactionsHeaderHeight : 0
    }

    private func refreshStickySectionHeader() {
        guard !isSearchActive else {
            stickySectionID = nil
            return
        }

        let pinY = sectionHeaderPinY
        let candidates = sectionHeaderFrames.filter { $0.minY <= pinY + 0.5 }
        guard let leading = candidates.max(by: { $0.minY < $1.minY }) else {
            stickySectionID = nil
            return
        }

        stickySectionID = leading.minY < pinY - 0.5 ? leading.id : nil
    }

    @ViewBuilder
    private func stickySectionHeader(for id: StickySectionID) -> some View {
        switch id {
        case .date(let date):
            dateSectionHeader(
                date: date,
                transactions: sortOrder.transactionsSorted(filteredDateTransactions[date] ?? [])
            )
        case .category(let categoryId):
            if let section = categorySections.first(where: { $0.id == categoryId }) {
                categorySectionHeader(section)
            }
        }
    }

    private func dateSectionHeader(
        date: Date,
        transactions: [Transaction],
        showsNetTotal: Bool = true
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(date.formattedDate())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))

            Spacer(minLength: 0)

            if showsNetTotal {
                sectionNetTotalLabel(for: transactions)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AdaptiveBrandSurface.background(for: colorScheme))
    }

    private func categorySectionHeader(_ section: CategorySection) -> some View {
        HStack(alignment: .center, spacing: 8) {
            CategoryIconBadge(
                symbolName: section.category.symbolName,
                colorHex: section.category.colorHex,
                size: 36,
                showsColorBackground: false
            )
            Text(categoryStore.localizedName(for: section.category))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))

            Spacer(minLength: 0)

            sectionNetTotalLabel(for: section.transactions)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AdaptiveBrandSurface.background(for: colorScheme))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .xpnseAdaptiveForeground(muted: true)

            TextField("home.search_placeholder", text: $searchText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFieldFocused)

            Button {
                closeSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .xpnseAdaptiveForeground(muted: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AdaptiveBrandSurface.fieldBackground(for: colorScheme))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AdaptiveBrandSurface.fieldBorder(for: colorScheme), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var listOptionsButton: some View {
        Menu {
            Section(L10n.tr("home.list_options.group")) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    let next: TransactionListGrouping = grouping == .category ? .date : .category
                    TransactionListPreferences.grouping = next
                    AppAnalytics.logButtonClick(
                        AppAnalytics.Button.toggleGroupByCategory,
                        source: AppAnalytics.Screen.home
                    )
                    withAnimation(.easeInOut(duration: 0.2)) {
                        grouping = next
                    }
                } label: {
                    if grouping == .category {
                        Label(L10n.tr("home.list_options.category"), systemImage: "checkmark")
                    } else {
                        Text(L10n.tr("home.list_options.category"))
                    }
                }
            }

            Section(L10n.tr("home.list_options.sort")) {
                ForEach(TransactionListSortOrder.allCases, id: \.rawValue) { order in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        guard sortOrder != order else { return }
                        TransactionListPreferences.sortOrder = order
                        AppAnalytics.logButtonClick(
                            order == .ascending
                                ? AppAnalytics.Button.setSortAscending
                                : AppAnalytics.Button.setSortDescending,
                            source: AppAnalytics.Screen.home
                        )
                        sortOrder = order
                    } label: {
                        if sortOrder == order {
                            Label(L10n.tr(order.titleKey), systemImage: "checkmark")
                        } else {
                            Text(L10n.tr(order.titleKey))
                        }
                    }
                }
            }

            Section(L10n.tr("home.list_options.filter")) {
                ForEach(TransactionListTypeFilter.filterOrder, id: \.0.rawValue) { flag, type in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        var next = typeFilter
                        next.set(flag, enabled: !typeFilter.contains(flag))
                        TransactionListPreferences.typeFilter = next
                        AppAnalytics.logButtonClick(
                            analyticsButton(for: flag),
                            source: AppAnalytics.Screen.home
                        )
                        typeFilter = next
                    } label: {
                        if typeFilter.contains(flag) {
                            Label(type.displayName, systemImage: "checkmark")
                        } else {
                            Text(type.displayName)
                        }
                    }
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    let next = !showUpcomingRecurring
                    TransactionListPreferences.showUpcomingRecurring = next
                    AppAnalytics.logButtonClick(
                        AppAnalytics.Button.toggleShowUpcomingRecurring,
                        source: AppAnalytics.Screen.home
                    )
                    showUpcomingRecurring = next
                } label: {
                    if showUpcomingRecurring {
                        Label(L10n.tr("home.list_options.upcoming"), systemImage: "checkmark")
                    } else {
                        Text(L10n.tr("home.list_options.upcoming"))
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                .frame(width: 36, height: 36)
                .background(AdaptiveBrandSurface.rowBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel(L10n.tr("home.list_options"))
        .simultaneousGesture(TapGesture().onEnded {
            AppAnalytics.logButtonClick(
                AppAnalytics.Button.openListOptions,
                source: AppAnalytics.Screen.home
            )
        })
    }

    private func analyticsButton(for filter: TransactionListTypeFilter) -> String {
        switch filter {
        case .expense: return AppAnalytics.Button.toggleFilterExpense
        case .income: return AppAnalytics.Button.toggleFilterIncome
        case .savings: return AppAnalytics.Button.toggleFilterSavings
        default: return AppAnalytics.Button.openListOptions
        }
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        if filteredSearchResults.isEmpty {
            Text("home.no_matching")
                .font(.system(size: 16, weight: .medium))
                .xpnseAdaptiveForeground(muted: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } else {
            VStack(spacing: 8) {
                ForEach(filteredSearchResults) { transaction in
                    TransactionItemView(transaction: transaction, subtitle: .category)
                }
            }
        }
    }

    private func dateSection(
        date: Date,
        transactions: [Transaction]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            dateSectionHeader(date: date, transactions: transactions)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: SectionHeaderFramesKey.self,
                            value: [
                                StickySectionFrame(
                                    id: .date(date),
                                    minY: geometry.frame(in: .named("transactionScroll")).minY
                                )
                            ]
                        )
                    }
                )

            VStack(spacing: 8) {
                ForEach(transactions) { transaction in
                    TransactionItemView(transaction: transaction, subtitle: .category)
                }
            }
        }
    }

    private func categorySection(_ section: CategorySection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            categorySectionHeader(section)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: SectionHeaderFramesKey.self,
                            value: [
                                StickySectionFrame(
                                    id: .category(section.id),
                                    minY: geometry.frame(in: .named("transactionScroll")).minY
                                )
                            ]
                        )
                    }
                )

            VStack(spacing: 8) {
                ForEach(section.transactions) { transaction in
                    TransactionItemView(
                        transaction: transaction,
                        subtitle: .date,
                        showsLeadingCategoryIcon: false
                    )
                }
            }
        }
    }

    private func upcomingSection(subtitle: TransactionItemSubtitle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(upcomingDateGroups, id: \.date) { group in
                VStack(alignment: .leading, spacing: 8) {
                    // Upcoming days show the date only — no section net total.
                    dateSectionHeader(
                        date: group.date,
                        transactions: [],
                        showsNetTotal: false
                    )

                    ForEach(group.items) { item in
                        UpcomingRecurringItemView(
                            item: item,
                            subtitle: subtitle,
                            showsLeadingCategoryIcon: grouping == .date
                        ) {
                            selectedRecurringForEdit = item.rule
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.tr("home.upcoming"))
    }

    private var noTransactionsFound: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                Text("home.no_transactions")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}
