//
//  DeviceSafeArea.swift
//  Xpnse
//

import UIKit

enum DeviceSafeArea {
    static var bottom: CGFloat {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        else {
            return 0
        }
        return window.safeAreaInsets.bottom
    }
}
