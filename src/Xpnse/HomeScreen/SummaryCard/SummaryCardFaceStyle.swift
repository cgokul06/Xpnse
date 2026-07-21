//
//  SummaryCardFaceStyle.swift
//  Xpnse
//

import SwiftUI

extension View {
    func summaryCardFaceBackground() -> some View {
        // POC: home summary cards use the Insights outlined panel language.
        xpnseOutlinedPanel()
    }

    func summaryCardShadow() -> some View {
        // Shadow is applied inside `xpnseOutlinedPanel()`.
        self
    }
}
