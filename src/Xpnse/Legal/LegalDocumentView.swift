//
//  LegalDocumentView.swift
//  Xpnse
//

import SwiftUI
import WebKit

/// Full-screen browser for Privacy Policy and Terms, with a close button.
struct LegalDocumentView: View {
    let document: LegalDocument

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            LegalWebView(url: document.url)
                .ignoresSafeArea(edges: .bottom)
                .gradientNavigationBackground()
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden()
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .bold()
                                .padding(.all, 8)
                        }
                        .foregroundStyle(AdaptiveBrandSurface.primaryForeground(for: colorScheme))
                    }

                    ToolbarItem(placement: .principal) {
                        Text(L10n.tr(document.titleKey))
                            .font(.title2)
                            .fontWeight(.bold)
                            .xpnseAdaptiveForeground()
                    }
                }
        }
        .onAppear {
            let screen = document == .privacyPolicy
                ? AppAnalytics.Screen.legalPrivacy
                : AppAnalytics.Screen.legalTerms
            AppAnalytics.logScreen(screen)
        }
    }
}

private struct LegalWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
