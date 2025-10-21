//
//  NavigationCoordinator.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI
import Combine

final class NavigationCoordinator<R: Route>: ObservableObject {
    @Published var path: [R] = []
    @Published var presentedSheet: R?
    @Published var presentedFullScreenCover: R?
    
    func push(_ route: R) {
        withAnimation {
            path.append(route)
        }
    }
    
    func pop() {
        withAnimation {
            _ = path.popLast()
        }
    }
    
    func popToRoot() {
        withAnimation {
            path.removeAll()
        }
    }
    
    func presentSheet(_ route: R) {
        presentedSheet = route
    }
    
    func dismissSheet() {
        presentedSheet = nil
    }
    
    func presentFullScreen(_ route: R) {
        presentedFullScreenCover = route
    }
    
    func dismissFullScreen() {
        presentedFullScreenCover = nil
    }
}
