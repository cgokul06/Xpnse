//
//  BillScannerView.swift
//  Xpnse
//
//  Created by Gokul C on 27/07/25.
//

import PhotosUI
import SwiftUI
import UIKit

struct BillScannerView: View {
    @ObservedObject var billScannerService: BillScannerService
    @EnvironmentObject private var homeCoordinator: NavigationCoordinator<HomeRoute>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingCamera = false
    @StateObject private var imagePicker = ImagePicker()

    private var showsErrorAlert: Binding<Bool> {
        Binding(
            get: { billScannerService.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    billScannerService.errorMessage = nil
                }
            }
        )
    }

    var body: some View {
        NavigationView {
            ZStack {
                PrimaryGradient()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        heroCard

                        VStack(spacing: 12) {
                            Button {
                                AppAnalytics.logButtonClick(AppAnalytics.Button.takePhoto, source: AppAnalytics.Screen.scan)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showingCamera = true
                            } label: {
                                actionButtonLabel(
                                    iconName: "camera.fill",
                                    title: L10n.tr("scanner.take_photo")
                                )
                            }
                            .buttonStyle(
                                XpnsePrimaryButtonStyle.defaultButton(
                                    isDisabled: .constant(false),
                                    isLoading: .constant(false)
                                )
                            )

                            PhotosPicker(
                                selection: $imagePicker.imageSelections,
                                maxSelectionCount: 1,
                                matching: .images
                            ) {
                                actionButtonLabel(
                                    iconName: "photo.on.rectangle.angled",
                                    title: L10n.tr("scanner.select_library")
                                )
                            }
                            .buttonStyle(
                                XpnseSecondaryButtonStyle.defaultButton(
                                    isDisabled: .constant(false),
                                    isLoading: .constant(false)
                                )
                            )
                            .simultaneousGesture(TapGesture().onEnded {
                                AppAnalytics.logButtonClick(AppAnalytics.Button.selectLibrary, source: AppAnalytics.Screen.scan)
                            })
                        }

                        if billScannerService.isScanning {
                            scanningCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
            .gradientNavigationBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .xpnseAdaptiveForeground()
                            .bold()
                            .padding(.all, 8)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("scanner.title")
                        .font(.title2)
                        .fontWeight(.bold)
                        .xpnseAdaptiveForeground()
                }
            }
            .onChange(of: billScannerService.extractedTransaction) { _, newTxn in
                guard newTxn != nil else { return }

                if homeCoordinator.path == [.billScanner] {
                    homeCoordinator.path = [.transactions]
                } else {
                    dismiss()
                }
            }
        }
        .navigationBarBackButtonHidden()
        .onChange(of: imagePicker.uiImages) { _, images in
            if let image = images.first {
                Task {
                    await billScannerService.scanBill(from: image)
                }
            }
        }
        .alert("common.error", isPresented: showsErrorAlert) {
            Button("common.ok", role: .cancel) {
                billScannerService.errorMessage = nil
            }
        } message: {
            Text(billScannerService.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                Task {
                    await billScannerService.scanBill(from: image)
                }
            } onCancel: {}
            .ignoresSafeArea()
        }
        .onAppear {
            AppAnalytics.logScreen(AppAnalytics.Screen.scan)
        }
    }

    private var heroCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AdaptiveBrandSurface.rowBackground(for: colorScheme, emphasized: true))
                    .frame(width: 88, height: 88)

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 36, weight: .semibold))
                    .xpnseAdaptiveForeground()
            }

            Text("scanner.hero_title")
                .font(.system(size: 22, weight: .bold))
                .xpnseAdaptiveForeground()

            Text("scanner.hero_subtitle")
                .font(.system(size: 16, weight: .regular))
                .xpnseAdaptiveForeground(muted: true)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .xpnseOutlinedPanel()
    }

    private var scanningCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(
                    CircularProgressViewStyle(
                        tint: AdaptiveBrandSurface.primaryForeground(for: colorScheme)
                    )
                )
                .scaleEffect(1.2)

            Text("scanner.analyzing")
                .font(.system(size: 16, weight: .semibold))
                .xpnseAdaptiveForeground()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .xpnseOutlinedPanel()
    }

    private func actionButtonLabel(iconName: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))

            Text(title)
                .font(.system(size: 18, weight: .semibold))
        }
    }
}
