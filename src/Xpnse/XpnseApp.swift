//
//  XpnseApp.swift
//  Xpnse
//
//  Created by Gokul C on 05/07/25.
//

import SwiftUI

@main
struct XpnseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            CoordinatedContentView()
        }
    }
}
