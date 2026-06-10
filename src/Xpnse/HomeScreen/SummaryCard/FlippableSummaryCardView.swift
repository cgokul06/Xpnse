//
//  FlippableSummaryCardView.swift
//  Xpnse
//

import SwiftUI

struct FlippableSummaryCardView: View {
    let monthKey: Int
    let summary: TransactionSummary?

    @State private var isShowingDonut = false

    var body: some View {
        ZStack {
            SummaryCardView(
                totalBalance: summary?.totalBalance ?? 0,
                income: summary?.totalIncome ?? 0,
                expenses: summary?.totalExpenses ?? 0,
                onFlip: { flipCard() }
            )
            .opacity(isShowingDonut ? 0 : 1)
            .rotation3DEffect(.degrees(0), axis: (x: 0, y: 1, z: 0))

            ExpenseDonutSummaryCardView(
                summary: summary,
                onFlip: { flipCard() }
            )
            .opacity(isShowingDonut ? 1 : 0)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(height: SummaryCardMetrics.height)
        .summaryCardShadow()
        .rotation3DEffect(
            .degrees(isShowingDonut ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .animation(.easeInOut(duration: 0.34), value: isShowingDonut)
        .onChange(of: monthKey) { _, _ in
            isShowingDonut = false
        }
    }

    private func flipCard() {
        isShowingDonut.toggle()
    }
}
