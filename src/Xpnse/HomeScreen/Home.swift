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
    @State private var monthScrollAnchors: [Int: TransactionListPersistedAnchor] = [:]
    @State private var isSummaryCardShowingDonut = false
    @State private var transactionListGrouping: TransactionListGrouping = .date
    @State private var bottomBarHiddenAmount: CGFloat = 0
    @State private var isTransactionSearchActive = false

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
        max(0, HomeBottomBarMetrics.visibleListScrollInset - displayedBottomBarHiddenAmount)
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
                        Task {
                            await homeViewModel.prefetchIfNeeded(currentKey: homeViewModel.currentKey)
                        }
                    }
            }

            if homeViewModel.isLoading {
                ProgressView()
            }
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
            insightsFloatingButton
        }
        .onChange(of: homeCoordinator.path.count) { oldCount, newCount in
            guard newCount < oldCount else { return }
            resetBottomActionBar()
        }
    }

    private func resetBottomActionBar() {
        bottomBarHiddenAmount = 0
    }

    private var insightsFloatingButton: some View {
        Button {
            homeCoordinator.push(.insights)
        } label: {
            Image(systemName: "chart.bar.xaxis")
        }
        .buttonStyle(
            XpnseSquareIconButtonStyle.defaultButton(
                bgColor: XpnseColorKey.secondaryButtonBGColor,
                isDisabled: .constant(false),
                isLoading: .constant(false)
            )
        )
        .accessibilityLabel("SnapLedger Insights")
        .padding(.trailing, 16)
        .padding(.bottom, contentBottomInset + 8)
        .offset(y: displayedBottomBarHiddenAmount)
        .opacity(1 - bottomBarHideProgress)
        .allowsHitTesting(bottomBarHideProgress < 1)
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    self.homeCoordinator.push(.transactions)
                } label: {
                    Text("Add transaction")
                        .font(.system(size: 20, weight: .bold))
                }
                .buttonStyle(
                    XpnsePrimaryButtonStyle.defaultButton(
                        bgColor: XpnseColorKey.secondaryButtonBGColor,
                        isDisabled: .constant(false),
                        isLoading: .constant(false)
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: XpnseBottomBarMetrics.buttonHeight)

                if FoundationModelsAvailability.isAvailable {
                    Button {
                        self.homeCoordinator.push(.billScanner)
                    } label: {
                        Image(systemName: "doc.text.viewfinder")
                    }
                    .buttonStyle(
                        XpnseSquareIconButtonStyle.defaultButton(
                            bgColor: XpnseColorKey.secondaryButtonBGColor,
                            isDisabled: .constant(false),
                            isLoading: .constant(false)
                        )
                    )
                    .accessibilityLabel("Scan bill")
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
        guard update.visibleHeight > 0, !isTransactionSearchActive else { return }

        if update.offsetY <= 0 {
            bottomBarHiddenAmount = 0
            return
        }

        if update.previousOffsetY > update.maxOffset || update.offsetY > update.maxOffset {
            return
        }

        let delta = update.delta
        if abs(delta) > HomeBottomBarMetrics.programmaticScrollDeltaThreshold {
            bottomBarHiddenAmount = min(
                update.offsetY,
                HomeBottomBarMetrics.collapseDistance
            )
            return
        }

        bottomBarHiddenAmount = min(
            max(0, bottomBarHiddenAmount + delta),
            HomeBottomBarMetrics.collapseDistance
        )
    }

    private var topView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SnapLedger")
                    .font(.title2)
                    .fontWeight(.bold)
                    .xpnseAdaptiveForeground()

                Text("Track your expenses")
                    .xpnseAdaptiveForeground(muted: true)
                    .font(.headline)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
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
        transactionListPanel(for: key, pageWidth: pageWidth)
            .id(key)
            .frame(width: pageWidth, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
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
                    } else {
                        monthDragAxis = .vertical
                        return
                    }
                }

                guard monthDragAxis == .horizontal else { return }
                monthDragOffset = rubberBandedOffset(horizontal, pageWidth: pageWidth)
            }
            .onEnded { value in
                defer { monthDragAxis = nil }

                guard monthDragAxis == .horizontal else {
                    if monthDragOffset != 0 {
                        snapMonthOffsetToZero()
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
        }
    }

    private func commitMonthChange(direction: Int, pageWidth: CGFloat) {
        let targetOffset: CGFloat = direction > 0 ? -pageWidth : pageWidth

        withAnimation(MonthPagerAnimation.slide) {
            monthDragOffset = targetOffset
        } completion: {
            applyMonthChange(direction: direction)
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
            savedScrollAnchor: monthScrollAnchors[key],
            onScrollAnchorChange: { anchor in
                monthScrollAnchors[key] = anchor
            },
            onScrollOffsetChange: key == homeViewModel.currentKey
                ? handleTransactionListScroll
                : nil,
            onListAppear: key == homeViewModel.currentKey
                ? resetBottomActionBar
                : nil,
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

        return HStack(spacing: 12) {
            Image(systemName: "arrowtriangle.left.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(XpnseColorKey.black.color)
                .frame(width: 12)

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

            Image(systemName: "arrowtriangle.right.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(canGoForward ? XpnseColorKey.black.color : XpnseColorKey.disabled.color)
                .frame(width: 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(XpnseColorKey.secondaryButtonBGColor.color)
    }

    private func monthYearLabel(for key: Int, width: CGFloat) -> some View {
        Text(homeViewModel.transactionSummaryDict[key]?.dateRangeText ?? "")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(XpnseColorKey.black.color)
            .frame(width: width)
    }
}
