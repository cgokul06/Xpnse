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

struct Home: View {
    @EnvironmentObject var homeCoordinator: NavigationCoordinator<HomeRoute>
    @StateObject private var homeViewModel: HomeScreenViewModel = HomeScreenViewModel()
    @State private var monthDragOffset: CGFloat = 0
    @State private var monthDragAxis: MonthDragAxis?
    @State private var monthScrollAnchors: [Int: TransactionListPersistedAnchor] = [:]

    private var isMonthDragActive: Bool {
        monthDragOffset != 0 || monthDragAxis == .horizontal
    }

    var body: some View {
        ZStack {
            PrimaryGradient()

            if !homeViewModel.transactionSummaryDict.isEmpty {
                contentView
                    .navigationBarTitleDisplayMode(.inline)
                    .onChange(of: self.homeViewModel.currentKey) { _, newKey in
                        Task {
                            await homeViewModel.prefetchIfNeeded(currentKey: newKey)
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
            let currentSummary = homeViewModel.transactionSummaryDict[homeViewModel.currentKey]

            VStack(spacing: 16) {
                topView

                VStack(spacing: 16) {
                    dateSwitchBar(pageWidth: pageWidth)

                    summaryCardPagerStrip(pageWidth: pageWidth)

                    TransactionListView(
                        monthKey: homeViewModel.currentKey,
                        dateTransactions: currentSummary?.transactions ?? [:],
                        savedScrollAnchor: monthScrollAnchors[homeViewModel.currentKey],
                        onScrollAnchorChange: { anchor in
                            monthScrollAnchors[homeViewModel.currentKey] = anchor
                        },
                        isScrollDisabled: isMonthDragActive
                    )
                    .padding(.horizontal, 16)
                    .overlay(alignment: .bottom) {
                        DividerGradient()
                            .frame(height: 12)
                            .allowsHitTesting(false)
                    }
                    .frame(maxHeight: .infinity)
                }
                .simultaneousGesture(monthDragGesture(pageWidth: pageWidth, swipeThreshold: swipeThreshold))
                .padding(.bottom, XpnseBottomBarMetrics.buttonHeight + 16)
            }
            .topSpacingIfNoSafeArea()
        }
        .overlay(
            alignment: .bottom,
            content: {
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
            })
    }

    private var topView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Xpnse")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(XpnseColorKey.white.color)

                Text("Track your expenses")
                    .foregroundColor(XpnseColorKey.white.color)
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
                        .foregroundStyle(XpnseColorKey.white.color)
                }
            }
        }
        .padding([.horizontal], 16)
    }

    private func summaryCardPagerStrip(pageWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            summaryCardPanel(for: homeViewModel.currentKey - 1, pageWidth: pageWidth)
            summaryCardPanel(for: homeViewModel.currentKey, pageWidth: pageWidth)
            summaryCardPanel(for: homeViewModel.currentKey + 1, pageWidth: pageWidth)
        }
        .offset(x: -pageWidth + monthDragOffset)
        .frame(width: pageWidth, height: SummaryCardMetrics.height, alignment: .leading)
        .clipped()
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
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

    private func summaryCardPanel(for key: Int, pageWidth: CGFloat) -> some View {
        let txnSummary = homeViewModel.transactionSummaryDict[key]

        return FlippableSummaryCardView(
            monthKey: key,
            summary: txnSummary
        )
        .padding(.horizontal, 16)
        .frame(width: pageWidth)
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
