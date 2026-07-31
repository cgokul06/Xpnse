//
//  AppVersionProviding.swift
//  Xpnse
//

import Foundation

protocol AppVersionProviding {
    var shortVersion: String { get }
    var buildNumber: String { get }
}

struct BundleAppVersionProvider: AppVersionProviding {
    var shortVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}

struct FixedAppVersionProvider: AppVersionProviding {
    let shortVersion: String
    let buildNumber: String
}

final class MutableAppVersionProvider: AppVersionProviding {
    var shortVersion: String
    var buildNumber: String

    init(shortVersion: String, buildNumber: String) {
        self.shortVersion = shortVersion
        self.buildNumber = buildNumber
    }
}
