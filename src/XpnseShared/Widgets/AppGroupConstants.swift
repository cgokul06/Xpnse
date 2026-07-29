//
//  AppGroupConstants.swift
//  Xpnse
//

import Foundation

enum AppGroupConstants {
    #if DEBUG
    static let identifier = "group.com.snapledgerapp.ios.shared"
    #else
    static let identifier = "group.com.snapledger.ios.shared"
    #endif
    static let snapshotFileName = "widget-month-snapshot.json"
    static let urlScheme = "snapledger"
}
