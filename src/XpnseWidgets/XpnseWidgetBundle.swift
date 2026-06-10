//
//  XpnseWidgetBundle.swift
//  XpnseWidgets
//

import SwiftUI
import WidgetKit

@main
struct XpnseWidgetBundle: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
        AddTransactionWidget()
    }
}
