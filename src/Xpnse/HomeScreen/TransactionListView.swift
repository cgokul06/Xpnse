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

struct TransactionListView: View {
    let monthKey: Int
    var summary: TransactionSummary?
    @Binding var isShowingDonut: Bool
    var dateTransactions: [Date: [Transaction]]
    @Binding var grouping: TransactionListGrouping
    var savedScrollAnchor: TransactionListPersistedAnchor?
    var onScrollAnchorChange: (TransactionListPersistedAnchor) -> Void
    var onScrollOffsetChange: ((TransactionListScrollUpdate) -> Void)?
    var onListAppear: (() -> Void)?
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
    @State private var pendingProgrammaticScroll: TransactionListPersistedAnchor?
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var debouncedSearchQuery = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool

    private static let summaryCardScrollThreshold: CGFloat = 176
    private static let searchDebounceInterval: Duration = .milliseconds(300)

    private var scrollContentBottomPadding: CGFloat {
        let safeAreaPadding = extendsToBottomSafeArea ? DeviceSafeArea.bottom : 0
        return scrollBottomInset + safeAreaPadding
    }

    private var dates: [Date] {
        dateTransactions.keys.sorted(by: >)
    }

    private var allTransactions: [Transaction] {
        dates.flatMap { dateTransactions[$0] ?? [] }
    }

    private var isSearchActive: Bool {
        !debouncedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredSearchResults: [Transaction] {
        let query = debouncedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        return allTransactions
            .filter { $0.title.localizedCaseInsensitiveContains(query) }
            .sorted { $0.date > $1.date }
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
                    transactions: transactions.sorted { $0.date > $1.date }
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

        Text("\(currency.symbol)\(AmountFormatter.format(displayAmount))")
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

    private var isPartiallyScrolled: Bool {
        guard scrollMetrics.isScrollable else { return false }
        guard scrollMetrics.visibleHeight > 0 else {
            return scrollMetrics.offsetY > 24
        }
        return scrollMetrics.offsetY > scrollMetrics.visibleHeight * 0.5
    }

    var body: some View {
        Group {
            if hasTransactions || isSearching {
                transactionScrollContent
            } else {
                noTransactionsFound
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onChange(of: dateTransactions) { _, _ in
            handleTransactionDataChange()
        }
        .onChange(of: grouping) { _, _ in
            scrollAnchor = .top
            onScrollAnchorChange(.top)
            pendingProgrammaticScroll = .top
        }
        .onChange(of: searchText) { _, newValue in
            scheduleSearchDebounce(for: newValue)
        }
        .onChange(of: debouncedSearchQuery) { _, _ in
            pendingProgrammaticScroll = .top
        }
        .onChange(of: monthKey) { _, _ in
            closeSearch()
        }
        .task {
            await categoryStore.load()
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
        searchDebounceTask?.cancel()
        searchDebounceTask = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            isSearching = false
            searchText = ""
            debouncedSearchQuery = ""
        }
        isSearchFieldFocused = false
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
        scrollMetrics = newMetrics

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
        case .date(let date):
            return grouping == .date && !dates.contains(date)
        case .category(let categoryId):
            return grouping == .category
                && !categorySections.contains(where: { $0.id == categoryId })
        }
    }

    private func revealNewestContent(topDate: Date?) {
        let target: TransactionListPersistedAnchor
        if scrollMetrics.isScrollable, grouping == .date, let topDate {
            target = .date(topDate)
        } else {
            target = .top
        }

        DispatchQueue.main.async {
            self.pendingProgrammaticScroll = target
        }
    }

    private func scrollToAnchor(_ anchor: TransactionListPersistedAnchor, proxy: ScrollViewProxy) {
        let resolvedAnchor = scrollMetrics.isScrollable ? anchor : .top

        scrollAnchor = resolvedAnchor
        onScrollAnchorChange(resolvedAnchor)

        var transaction = SwiftUI.Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(resolvedAnchor, anchor: .top)
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

        if !hasTransactions {
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
        guard let anchor else { return .top }

        switch anchor {
        case .top:
            return .top
        case .date(let date):
            guard grouping == .date, dates.contains(date) else { return .top }
            return anchor
        case .category(let categoryId):
            guard grouping == .category,
                  categorySections.contains(where: { $0.id == categoryId })
            else { return .top }
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
                VStack(spacing: 12) {
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

                    switch grouping {
                    case .date:
                        if isSearchActive {
                            searchResultsContent
                        } else {
                            ForEach(dates, id: \.self) { date in
                                dateSection(date: date, transactions: dateTransactions[date] ?? [])
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
            }
            .overlay(alignment: .top) {
                if isTransactionsHeaderPinned {
                    transactionsSectionHeader
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
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
                Text("Transactions")
                    .font(.system(size: 18, weight: .medium))
                    .xpnseAdaptiveForeground()

                groupingToggleButton

                Spacer(minLength: 0)

                Button {
                    activateSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                        .frame(width: 36, height: 36)
                        .background(AdaptiveBrandSurface.rowBackground(for: colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("Search transactions")
                .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AdaptiveBrandSurface.background(for: colorScheme))
        .animation(.easeInOut(duration: 0.25), value: isSearching)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .xpnseAdaptiveForeground(muted: true)

            TextField("Search by description", text: $searchText)
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

    private var groupingToggleButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.2)) {
                grouping = grouping == .date ? .category : .date
            }
        } label: {
            Image(systemName: grouping == .date ? "square.grid.2x2.fill" : "calendar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                .frame(width: 36, height: 36)
                .background(AdaptiveBrandSurface.rowBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel(grouping == .date ? "Group by category" : "Group by date")
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        if filteredSearchResults.isEmpty {
            Text("No matching transactions")
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

    private func dateSection(date: Date, transactions: [Transaction]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(date.formattedDate())
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))

                Spacer(minLength: 0)

                sectionNetTotalLabel(for: transactions)
            }

            VStack(spacing: 8) {
                ForEach(transactions) { transaction in
                    TransactionItemView(transaction: transaction, subtitle: .category)
                }
            }
        }
    }

    private func categorySection(_ section: CategorySection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                CategoryIconBadge(
                    symbolName: section.category.symbolName,
                    colorHex: section.category.colorHex,
                    size: 24
                )
                Text(section.category.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))

                Spacer(minLength: 0)

                sectionNetTotalLabel(for: section.transactions)
            }

            VStack(spacing: 8) {
                ForEach(section.transactions) { transaction in
                    TransactionItemView(transaction: transaction, subtitle: .date)
                }
            }
        }
    }

    private var noTransactionsFound: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                Text("No transactions found!")
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
