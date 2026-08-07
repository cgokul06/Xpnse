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
    static let sharedTextInboxFileName = "shared-text-inbox.json"
    static let urlScheme = "snapledger"

    /// Opens the main app to process shared text from the Share Extension.
    static var shareInboxURL: URL {
        URL(string: "\(urlScheme)://share-inbox")!
    }
}
