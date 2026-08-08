//
//  Home.swift
//  Xpnse
//
//  Created by Gokul C on 21/07/25.
//

import SwiftUI
import UIKit

enum SwipeDirection {
    case left, right
}

private enum MonthDragAxis {
    case horizontal
    case vertical
}

private enum MonthPagerAnimation {
    static let slide = Animation.easeOut(duration: 0.28)
}

private enum HomeBottomBarMetrics {
    static let collapseDistance: CGFloat = XpnseBottomBarMetrics.buttonHeight + 48
    static let contentInset: CGFloat = XpnseBottomBarMetrics.buttonHeight + 16
    static let visibleListScrollInset: CGFloat = 62
    static let programmaticScrollDeltaThreshold: CGFloat = 80
}

struct Home: View {
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var homeViewModel: HomeScreenViewModel = HomeScreenViewModel()
    @State private var monthDragOffset: CGFloat = 0
    @State private var monthDragAxis: MonthDragAxis?
    /// When false, only the current month mounts a full `TransactionListView` (neighbors are shells).
    /// Set true for the duration of a horizontal swipe / animated month change.
    @State private var mountsNeighborMonthLists = false
    @State private var monthScrollAnchors: [Int: TransactionListPersistedAnchor] = [:]
    @State private var isSummaryCardShowingDonut = false
    @State private var transactionListGrouping: TransactionListGrouping = TransactionListPreferences.grouping
    @State private var showUpcomingRecurring = TransactionListPreferences.showUpcomingRecurring
    @State private var listTypeFilter = TransactionListPreferences.typeFilter
    @State private var listSortOrder = TransactionListPreferences.sortOrder
    @State private var bottomBarHiddenAmount: CGFloat = 0
    @State private var isTransactionSearchActive = false
    @State private var featureFlags = FeatureFlags.shared
    @State private var isSummaryCardOffscreen = false
    @State private var scrollToTopTick: UInt = 0

    private var displayedBottomBarHiddenAmount: CGFloat {
        isTransactionSearchActive
            ? HomeBottomBarMetrics.collapseDistance
            : bottomBarHiddenAmount
    }

    private var bottomBarHideProgress: CGFloat {
        guard HomeBottomBarMetrics.collapseDistance > 0 else { return 0 }
        return min(1, max(0, displayedBottomBarHiddenAmount / HomeBottomBarMetrics.collapseDistance))
    }

    private var contentBottomInset: CGFloat {
        max(0, HomeBottomBarMetrics.contentInset - displayedBottomBarHiddenAmount)
    }

    private var listScrollBottomInset: CGFloat {
        // Keep list bottom padding stable while the action bar hides. Shrinking this
        // in lockstep with the bar can make short months non-scrollable mid-offset.
        HomeBottomBarMetrics.visibleListScrollInset
    }

    var body: some View {
        ZStack {
            PrimaryGradient()

            if !homeViewModel.transactionSummaryDict.isEmpty {
                contentView
                    .navigationBarTitleDisplayMode(.inline)
                    .onChange(of: self.homeViewModel.currentKey) { _, _ in
                        bottomBarHiddenAmount = 0
                        isTransactionSearchActive = false
                        isSummaryCardOffscreen = false
                        Task {
                            await homeViewModel.prefetchIfNeeded(currentKey: homeViewModel.currentKey)
                        }
                    }
            }

            if homeViewModel.isLoading {
                ProgressView()
            }
        }
        .onAppear {
            AppAnalytics.logScreen(AppAnalytics.Screen.home)
        }
    }

    private var contentView: some View {
        GeometryReader { geometry in
            let pageWidth = geometry.size.width
            let swipeThreshold = pageWidth * 0.15

            VStack(spacing: 16) {
                topView

                VStack(spacing: 16) {
                    dateSwitchBar(pageWidth: pageWidth)

                    monthContentPagerStrip(pageWidth: pageWidth)
                }
                .simultaneousGesture(monthDragGesture(pageWidth: pageWidth, swipeThreshold: swipeThreshold))
                .padding(.bottom, contentBottomInset)
            }
            .topSpacingIfNoSafeArea()
        }
        .ignoresSafeArea(.container, edges: displayedBottomBarHiddenAmount > 0 ? .bottom : [])
        .overlay(alignment: .bottom) {
            bottomActionBar
        }
        .overlay(alignment: .bottomTrailing) {
            floatingTrailingButtons
        }
        .onChange(of: homeCoordinator.path.count) { oldCount, newCount in
            guard newCount < oldCount else { return }
            resetBottomActionBar()
        }
    }

    private var floatingTrailingButtons: some View {
        VStack(spacing: 12) {
            if isSummaryCardOffscreen {
                scrollToTopFloatingButton
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.55, anchor: .bottom)
                                .combined(with: .opacity)
                                .combined(with: .offset(y: 12)),
                            removal: .scale(scale: 0.55, anchor: .bottom)
                                .combined(with: .opacity)
                                .combined(with: .offset(y: 12))
                        )
                    )
            }

            if featureFlags.insightsEnabled {
                insightsFloatingButton
            }
        }
        .padding(.trailing, 16)
        // Track the add bar: move down as it collapses, keep an on-screen floor gap.
        .padding(.bottom, max(16, contentBottomInset + 8))
        .animation(.easeInOut(duration: 0.2), value: contentBottomInset)
        .animation(
            .spring(response: 0.34, dampingFraction: 0.78),
            value: isSummaryCardOffscreen
        )
    }

    private func resetBottomActionBar() {
        bottomBarHiddenAmount = 0
    }

    private var scrollToTopFloatingButton: some View {
        Button {
            AppAnalytics.logButtonClick(AppAnalytics.Button.scrollToTop, source: AppAnalytics.Screen.home)
            scrollToTopTick &+= 1
        } label: {
            Image(systemName: "chevron.up")
        }
        .buttonStyle(
            XpnseSquareIconButtonStyle.defaultButton(
                isDisabled: .constant(false),
                isLoading: .constant(false)
            )
        )
        .accessibilityLabel(L10n.tr("home.scroll_to_top_a11y"))
    }

    private var insightsFloatingButton: some View {
        Button {
            AppAnalytics.logButtonClick(AppAnalytics.Button.openInsights, source: AppAnalytics.Screen.home)
            AppAnalytics.logFeatureExposure(
                featureKey: FeatureFlags.Key.insightsEnabled.rawValue,
                enabled: true
            )
            homeCoordinator.push(.insights)
        } label: {
            Image(systemName: "chart.bar.xaxis")
        }
        .buttonStyle(
            XpnseSquareIconButtonStyle.defaultButton(
                isDisabled: .constant(false),
                isLoading: .constant(false)
            )
        )
        .accessibilityLabel(L10n.tr("home.insights_a11y"))
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    AppAnalytics.logButtonClick(AppAnalytics.Button.addTransaction, source: AppAnalytics.Screen.home)
                    self.homeCoordinator.push(.transactions)
                } label: {
                    Text("home.add_transaction")
                        .font(.system(size: 20, weight: .bold))
                }
                .buttonStyle(
                    XpnsePrimaryButtonStyle.defaultButton(
                        isDisabled: .constant(false),
                        isLoading: .constant(false)
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: XpnseBottomBarMetrics.buttonHeight)

                if featureFlags.receiptScanEnabled, FoundationModelsAvailability.isAvailable {
                    Button {
                        AppAnalytics.logButtonClick(AppAnalytics.Button.openScan, source: AppAnalytics.Screen.home)
                        AppAnalytics.logFeatureExposure(
                            featureKey: FeatureFlags.Key.receiptScanEnabled.rawValue,
                            enabled: true
                        )
                        self.homeCoordinator.push(.billScanner)
                    } label: {
                        Image(systemName: "doc.text.viewfinder")
                    }
                    .buttonStyle(
                        XpnseSquareIconButtonStyle.defaultButton(
                            isDisabled: .constant(false),
                            isLoading: .constant(false)
                        )
                    )
                    .accessibilityLabel(L10n.tr("home.scan_bill"))
                }
            }
            .padding(.horizontal, 16)
        }
        .bottomSpacingIfNoSafeArea(8)
        .offset(y: displayedBottomBarHiddenAmount)
        .opacity(1 - bottomBarHideProgress)
        .allowsHitTesting(bottomBarHideProgress < 1)
    }

    private func handleTransactionListScroll(_ update: TransactionListScrollUpdate) {
        guard update.visibleHeight > 0 else { return }

        if isTransactionSearchActive {
            if isSummaryCardOffscreen {
                isSummaryCardOffscreen = false
            }
            return
        }

        let hasBalanceCard = monthHasTransactions(for: homeViewModel.currentKey)
        let summaryOffscreen = hasBalanceCard
            && update.offsetY >= SummaryCardMetrics.height + 12
        if isSummaryCardOffscreen != summaryOffscreen {
            isSummaryCardOffscreen = summaryOffscreen
        }

        if update.offsetY <= 0 {
            bottomBarHiddenAmount = 0
            return
        }

        if update.previousOffsetY > update.maxOffset || update.offsetY > update.maxOffset {
            return
        }

        let delta = update.delta
        let overflow = update.contentHeight - update.visibleHeight
        // Short months: hiding grows the viewport and eats overflow. If there isn't room to
        // fully collapse the bar, keep it fully visible — never leave it half-hidden.
        let minOverflowToCollapse =
            HomeBottomBarMetrics.collapseDistance + HomeBottomBarMetrics.contentInset
        if overflow < minOverflowToCollapse {
            bottomBarHiddenAmount = 0
            return
        }

        if abs(delta) > HomeBottomBarMetrics.programmaticScrollDeltaThreshold {
            bottomBarHiddenAmount = min(
                update.offsetY,
                HomeBottomBarMetrics.collapseDistance
            )
        } else {
            bottomBarHiddenAmount = min(
                max(0, bottomBarHiddenAmount + delta),
                HomeBottomBarMetrics.collapseDistance
            )
        }
    }

    private var topView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("home.title")
                    .font(.title2)
                    .fontWeight(.bold)
                    .xpnseAdaptiveForeground()

                Text("home.subtitle")
                    .xpnseAdaptiveForeground(muted: true)
                    .font(.headline)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    AppAnalytics.logButtonClick(AppAnalytics.Button.openSettings, source: AppAnalytics.Screen.home)
                    homeCoordinator.push(.settings)
                } label: {
                    Image(systemName: "gear")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                }
            }
        }
        .padding([.horizontal], 16)
    }

    private func monthContentPagerStrip(pageWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            monthContentPanel(for: homeViewModel.currentKey - 1, pageWidth: pageWidth)
            monthContentPanel(for: homeViewModel.currentKey, pageWidth: pageWidth)
            monthContentPanel(for: homeViewModel.currentKey + 1, pageWidth: pageWidth)
        }
        .offset(x: -pageWidth + monthDragOffset)
        .frame(width: pageWidth, alignment: .topLeading)
        .clipped()
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            DividerGradient()
                .frame(height: 12)
                .allowsHitTesting(false)
        }
    }

    private func monthContentPanel(for key: Int, pageWidth: CGFloat) -> some View {
        Group {
            if shouldMountFullMonthList(for: key) {
                transactionListPanel(for: key, pageWidth: pageWidth)
            } else {
                monthPlaceholderPanel()
            }
        }
        .id(key)
        .frame(width: pageWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private func shouldMountFullMonthList(for key: Int) -> Bool {
        key == homeViewModel.currentKey || mountsNeighborMonthLists
    }

    /// Cheap stand-in so offscreen pager slots don't retain list / sticky / upcoming state.
    private func monthPlaceholderPanel() -> some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 16)
            .accessibilityHidden(true)
    }

    private func monthHasTransactions(for key: Int) -> Bool {
        !(homeViewModel.transactionSummaryDict[key]?.transactions.isEmpty ?? true)
    }

    private func monthDragGesture(pageWidth: CGFloat, swipeThreshold: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height

                if monthDragAxis == nil {
                    let absHorizontal = abs(horizontal)
                    let absVertical = abs(vertical)
                    guard max(absHorizontal, absVertical) > 12 else { return }

                    if absHorizontal > absVertical * 1.25 {
                        monthDragAxis = .horizontal
                        mountsNeighborMonthLists = true
                    } else {
                        monthDragAxis = .vertical
                        return
                    }
                }

                guard monthDragAxis == .horizontal else { return }
                if !mountsNeighborMonthLists {
                    mountsNeighborMonthLists = true
                }
                monthDragOffset = rubberBandedOffset(horizontal, pageWidth: pageWidth)
            }
            .onEnded { value in
                defer { monthDragAxis = nil }

                guard monthDragAxis == .horizontal else {
                    if monthDragOffset != 0 {
                        snapMonthOffsetToZero()
                    } else {
                        mountsNeighborMonthLists = false
                    }
                    return
                }

                handleMonthDragEnded(
                    translation: value.translation.width,
                    pageWidth: pageWidth,
                    swipeThreshold: swipeThreshold
                )
            }
    }

    private func rubberBandedOffset(_ offset: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let canGoForward = homeViewModel.currentKey < homeViewModel.maxFuturisticRange
        let canGoBackward = true

        if offset < 0, !canGoForward {
            return offset * 0.25
        }
        if offset > 0, !canGoBackward {
            return offset * 0.25
        }
        return max(-pageWidth, min(pageWidth, offset))
    }

    private func handleMonthDragEnded(translation: CGFloat, pageWidth: CGFloat, swipeThreshold: CGFloat) {
        let canGoForward = homeViewModel.currentKey < homeViewModel.maxFuturisticRange

        if translation <= -swipeThreshold, canGoForward {
            commitMonthChange(direction: 1, pageWidth: pageWidth)
        } else if translation >= swipeThreshold {
            commitMonthChange(direction: -1, pageWidth: pageWidth)
        } else {
            snapMonthOffsetToZero()
        }
    }

    private func snapMonthOffsetToZero() {
        withAnimation(MonthPagerAnimation.slide) {
            monthDragOffset = 0
        } completion: {
            mountsNeighborMonthLists = false
        }
    }

    private func commitMonthChange(direction: Int, pageWidth: CGFloat) {
        let targetOffset: CGFloat = direction > 0 ? -pageWidth : pageWidth
        let needsNeighborMount = !mountsNeighborMonthLists
        mountsNeighborMonthLists = true

        let runSlide = {
            withAnimation(MonthPagerAnimation.slide) {
                monthDragOffset = targetOffset
            } completion: {
                applyMonthChange(direction: direction)
                mountsNeighborMonthLists = false
            }
        }

        if needsNeighborMount {
            // Button-driven changes: mount neighbors one frame before sliding.
            Task { @MainActor in
                await Task.yield()
                runSlide()
            }
        } else {
            runSlide()
        }
    }

    private func applyMonthChange(direction: Int) {
        var transaction = SwiftUI.Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            homeViewModel.currentKey += direction
            monthDragOffset = 0
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func transactionListPanel(for key: Int, pageWidth: CGFloat) -> some View {
        let txnSummary = homeViewModel.transactionSummaryDict[key]
        let hasTransactions = monthHasTransactions(for: key)

        return TransactionListView(
            monthKey: key,
            summary: hasTransactions ? txnSummary : nil,
            isShowingDonut: $isSummaryCardShowingDonut,
            dateTransactions: txnSummary?.transactions ?? [:],
            grouping: $transactionListGrouping,
            showUpcomingRecurring: $showUpcomingRecurring,
            typeFilter: $listTypeFilter,
            sortOrder: $listSortOrder,
            savedScrollAnchor: monthScrollAnchors[key],
            onScrollAnchorChange: { anchor in
                monthScrollAnchors[key] = anchor
            },
            onScrollOffsetChange: key == homeViewModel.currentKey
                ? handleTransactionListScroll
                : nil,
            onListAppear: key == homeViewModel.currentKey
                ? {
                    resetBottomActionBar()
                    isSummaryCardOffscreen = false
                }
                : nil,
            scrollToTopTick: key == homeViewModel.currentKey ? scrollToTopTick : 0,
            isSearching: key == homeViewModel.currentKey
                ? $isTransactionSearchActive
                : .constant(false),
            scrollBottomInset: listScrollBottomInset,
            extendsToBottomSafeArea: displayedBottomBarHiddenAmount > 0
        )
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private func dateSwitchBar(pageWidth: CGFloat) -> some View {
        let canGoForward = homeViewModel.currentKey < homeViewModel.maxFuturisticRange
        let canChangeMonth = monthDragOffset == 0 && monthDragAxis == nil

        return HStack(spacing: 12) {
            Button {
                guard canChangeMonth else { return }
                AppAnalytics.logButtonClick(AppAnalytics.Button.monthPrevious, source: AppAnalytics.Screen.home)
                commitMonthChange(direction: -1, pageWidth: pageWidth)
            } label: {
                Image(systemName: "arrowtriangle.left.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .xpnseAdaptiveForeground()
                    .frame(width: 12, height: 12)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("home.prev_month"))

            GeometryReader { geometry in
                let textWidth = geometry.size.width
                let scaledOffset = pageWidth > 0
                    ? -textWidth + monthDragOffset * (textWidth / pageWidth)
                    : -textWidth

                HStack(spacing: 0) {
                    monthYearLabel(for: homeViewModel.currentKey - 1, width: textWidth)
                    monthYearLabel(for: homeViewModel.currentKey, width: textWidth)
                    monthYearLabel(for: homeViewModel.currentKey + 1, width: textWidth)
                }
                .offset(x: scaledOffset)
                .frame(width: textWidth, alignment: .leading)
                .clipped()
            }
            .frame(height: 20)

            Button {
                guard canChangeMonth, canGoForward else { return }
                AppAnalytics.logButtonClick(AppAnalytics.Button.monthNext, source: AppAnalytics.Screen.home)
                commitMonthChange(direction: 1, pageWidth: pageWidth)
            } label: {
                Image(systemName: "arrowtriangle.right.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(
                        canGoForward
                            ? AdaptiveBrandSurface.primaryForeground(for: colorScheme)
                            : AdaptiveBrandSurface.mutedForeground(for: colorScheme).opacity(0.45)
                    )
                    .frame(width: 12, height: 12)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
            .accessibilityLabel(L10n.tr("home.next_month"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .xpnseOutlinedPanel()
        .padding(.horizontal, 16)
    }

    private func monthYearLabel(for key: Int, width: CGFloat) -> some View {
        Text(homeViewModel.transactionSummaryDict[key]?.dateRangeText ?? "")
            .font(.system(size: 16, weight: .medium))
            .xpnseAdaptiveForeground()
            .frame(width: width)
    }
}
