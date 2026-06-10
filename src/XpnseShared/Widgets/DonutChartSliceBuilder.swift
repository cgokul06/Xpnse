//
//  DonutChartSliceBuilder.swift
//  Xpnse
//

import Foundation

enum DonutChartSliceBuilder {
    static func chartSlices(
        legendSlices: [WidgetDonutSlice],
        allSlices: [WidgetDonutSlice],
        income: Double
    ) -> [WidgetDonutSlice] {
        guard !legendSlices.isEmpty else {
            return allSlices.filter(\.isRemainder)
        }

        if income <= 0 {
            return legendSlices
        }

        let expenseSum = legendSlices.reduce(0) { $0 + $1.amount }
        guard expenseSum > income else { return allSlices }

        let scale = income / expenseSum
        return legendSlices.map { slice in
            WidgetDonutSlice(
                id: slice.id,
                name: slice.name,
                amount: slice.amount * scale,
                colorHex: slice.colorHex,
                isRemainder: false
            )
        }
    }

    static func centerTitle(income: Double) -> String {
        income > 0 ? "Income" : "Expenses"
    }

    static func centerAmount(income: Double, expenses: Double) -> Double {
        income > 0 ? income : expenses
    }
}
