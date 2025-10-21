//
//  LoadingView.swift
//  Xpnse
//
//  Created by Gokul C on 26/07/25.
//

import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
}
