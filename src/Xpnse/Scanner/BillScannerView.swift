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
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showingCamera = true
                            } label: {
                                actionButtonLabel(
                                    iconName: "camera.fill",
                                    title: "Take Photo"
                                )
                            }

                            PhotosPicker(
                                selection: $imagePicker.imageSelections,
                                maxSelectionCount: 1,
                                matching: .images
                            ) {
                                actionButtonLabel(
                                    iconName: "photo.on.rectangle.angled",
                                    title: "Select from Library"
                                )
                            }
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
                    Text("Scan Bill")
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
        .alert("Error", isPresented: showsErrorAlert) {
            Button("OK", role: .cancel) {
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
    }

    private var heroCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 88, height: 88)

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("Scan a receipt")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text("Take a photo or choose an image to extract amount, date, and category automatically.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(XpnseColorKey.summaryCard.color)
        .xpnseRoundedCorner(16)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 8)
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

            Text("Analyzing bill...")
                .font(.system(size: 16, weight: .semibold))
                .xpnseAdaptiveForeground()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AdaptiveBrandSurface.elevatedSurfaceBackground(for: colorScheme))
        .xpnseRoundedCorner(16)
    }

    private func actionButtonLabel(iconName: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))

            Text(title)
                .font(.system(size: 18, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(XpnseColorKey.secondaryButtonBGColor.color)
        .xpnseRoundedCorner()
    }
}
