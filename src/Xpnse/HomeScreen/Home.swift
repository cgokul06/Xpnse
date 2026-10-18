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
    /// Ignore tiny geometry jitter so hide only follows a real downward move.
    static let hideThreshold: CGFloat = 8
    /// Any real upward move should reveal the bar, including slow drags.
    static let revealThreshold: CGFloat = 1
    /// Treat this offset as the top of the list and keep the action bar visible.
    static let topRevealOffset: CGFloat = 2
    static let listBottomPaddingExtra: CGFloat = 10
}

private enum HomeBottomBarAnimation {
    static let visibility = Animation.easeInOut(duration: 0.28)
}

struct Home: View {
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var isBottomActionBarHidden = false
    @State private var isTransactionSearchActive = false
    @State private var featureFlags = FeatureFlags.shared
    @State private var isSummaryCardOffscreen = false
    @State private var scrollToTopTick: UInt = 0
    @State private var lastLoggedHomeState: AppAnalytics.FeatureState?

    private var isBottomBarVisuallyHidden: Bool {
        isTransactionSearchActive || isBottomActionBarHidden
    }

    private var listScrollBottomInset: CGFloat {
        HomeBottomBarMetrics.contentInset + HomeBottomBarMetrics.listBottomPaddingExtra
    }

    private var bottomBarHideOffset: CGFloat {
        HomeBottomBarMetrics.collapseDistance + DeviceSafeArea.bottom
    }

    private var floatingButtonsBottomPadding: CGFloat {
        let safeBottom = DeviceSafeArea.bottom
        if isBottomBarVisuallyHidden {
            return max(16, safeBottom + 8)
        }
        return HomeBottomBarMetrics.contentInset + safeBottom + 8
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                PrimaryGradient()

                if !homeViewModel.transactionSummaryDict.isEmpty {
                    contentView
                        .navigationBarTitleDisplayMode(.inline)
                        .onChange(of: self.homeViewModel.currentKey) { _, _ in
                            isBottomActionBarHidden = false
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

            if !homeViewModel.transactionSummaryDict.isEmpty {
                bottomActionBar
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .overlay(alignment: .bottomTrailing) {
            if !homeViewModel.transactionSummaryDict.isEmpty {
                floatingTrailingButtons
            }
        }
        .onAppear {
            AppAnalytics.logScreen(AppAnalytics.Screen.home)
            logFeatureAvailability()
            logHomeStateIfResolved()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                lastLoggedHomeState = nil
            case .active:
                logHomeStateIfResolved()
            default:
                break
            }
        }
        .onChange(of: resolvedHomeState) { _, _ in
            logHomeStateIfResolved()
        }
    }

    private var resolvedHomeState: AppAnalytics.FeatureState? {
        guard !homeViewModel.isLoading else { return nil }
        if homeViewModel.didFailToLoad { return .error }
        guard let count = homeViewModel.lifetimeTransactionCount else { return nil }
        return count == 0 ? .empty : .ready
    }

    private func logHomeStateIfResolved() {
        guard let state = resolvedHomeState, state != lastLoggedHomeState else { return }
        lastLoggedHomeState = state
        AppAnalytics.logEvent(AppAnalytics.Event.homeStateViewed, parameters: [
            AppAnalytics.Param.state: state.rawValue,
            AppAnalytics.Param.txnBucket: AppAnalytics.Bucket.txnCount(homeViewModel.lifetimeTransactionCount ?? 0)
        ])
        AppDiagnostics.markStartupCompleted(destination: "home")
    }

    private func logFeatureAvailability() {
        if !featureFlags.receiptScanEnabled {
            AppAnalytics.logFeatureUnavailable(feature: "scan", reason: "remote_config_off")
        } else if !FoundationModelsAvailability.isAvailable {
            AppAnalytics.logFeatureUnavailable(feature: "scan", reason: "apple_intelligence_unavailable")
        }
        if !featureFlags.insightsEnabled {
            AppAnalytics.logFeatureUnavailable(feature: "insights", reason: "remote_config_off")
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
            }
            .topSpacingIfNoSafeArea()
        }
        .ignoresSafeArea(.container, edges: .bottom)
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
        .padding(.bottom, floatingButtonsBottomPadding)
        .animation(HomeBottomBarAnimation.visibility, value: isBottomBarVisuallyHidden)
        .animation(
            .spring(response: 0.34, dampingFraction: 0.78),
            value: isSummaryCardOffscreen
        )
    }

    private func resetBottomActionBar() {
        isBottomActionBarHidden = false
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
            Color.clear
                .frame(height: 12)
                .allowsHitTesting(false)

            HStack(spacing: 12) {
                Button {
                    AppAnalytics.logButtonClick(AppAnalytics.Button.addTransaction, source: AppAnalytics.Screen.home)
                    self.homeCoordinator.push(.transactions(source: .home))
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
            .padding(.top, 8)
            .padding(.bottom, 8)

            // Occupy the home-indicator strip so the fill is flush with the screen bottom.
            Color.clear
                .frame(height: DeviceSafeArea.bottom > 0 ? DeviceSafeArea.bottom : 8)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .background {
            VStack(spacing: 0) {
                bottomBarTopFade
                AdaptiveBrandSurface.background(for: colorScheme)
            }
        }
        .offset(y: isBottomBarVisuallyHidden ? bottomBarHideOffset : 0)
        .allowsHitTesting(!isBottomBarVisuallyHidden)
        .accessibilityHidden(isBottomBarVisuallyHidden)
        .animation(HomeBottomBarAnimation.visibility, value: isBottomBarVisuallyHidden)
    }

    private var bottomBarTopFade: some View {
        let background = AdaptiveBrandSurface.background(for: colorScheme)
        return LinearGradient(
            colors: [
                background.opacity(0.2),
                background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 12)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
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

        let isAtTop = update.offsetY <= HomeBottomBarMetrics.topRevealOffset

        if isAtTop {
            setBottomActionBarHidden(false)
        } else if update.delta > HomeBottomBarMetrics.hideThreshold {
            setBottomActionBarHidden(true)
        } else if update.delta < -HomeBottomBarMetrics.revealThreshold {
            setBottomActionBarHidden(false)
        }
    }

    private func setBottomActionBarHidden(_ hidden: Bool) {
        guard isBottomActionBarHidden != hidden else { return }
        withAnimation(HomeBottomBarAnimation.visibility) {
            isBottomActionBarHidden = hidden
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
            commitMonthChange(direction: 1, pageWidth: pageWidth, navigationMethod: "swipe")
        } else if translation >= swipeThreshold {
            commitMonthChange(direction: -1, pageWidth: pageWidth, navigationMethod: "swipe")
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

    private func commitMonthChange(direction: Int, pageWidth: CGFloat, navigationMethod: String) {
        AppAnalytics.logEvent(AppAnalytics.Event.reportPeriodChanged, parameters: [
            AppAnalytics.Param.navigationMethod: navigationMethod,
            AppAnalytics.Param.direction: direction > 0 ? "next" : "previous"
        ])
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
            extendsToBottomSafeArea: true
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
                commitMonthChange(direction: -1, pageWidth: pageWidth, navigationMethod: "arrow")
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
            .accessibilityLabel(MonthlyCycleCopy.tr("home.prev_month"))

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
                commitMonthChange(direction: 1, pageWidth: pageWidth, navigationMethod: "arrow")
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
            .accessibilityLabel(MonthlyCycleCopy.tr("home.next_month"))
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
