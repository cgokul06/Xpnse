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
        let slices = allSlices.filter { $0.amount > 0 }
        return slices.isEmpty ? legendSlices : slices
    }

    static func centerTitle(income: Double) -> String {
        "Balance"
    }

    static func centerAmount(income: Double, expenses: Double, savings: Double = 0) -> Double {
        income - expenses - savings
    }
}
