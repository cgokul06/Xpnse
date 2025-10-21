//
//  BillScannerView.swift
//  Xpnse
//
//  Created by Gokul C on 27/07/25.
//

import PhotosUI
import SwiftUI
import VisionKit

struct BillScannerView: View {
    @StateObject var billScannerService: BillScannerService = BillScannerService()
    @Environment(\.dismiss) private var dismiss
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @StateObject var imagePicker = ImagePicker()

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        Text("Scan Bill")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Take a photo or select an image to automatically extract transaction details")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            showingCamera = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "camera")
                                    .font(.title2)
                                Text("Take Photo")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(XpnseColorKey.primaryButtonBGColor.color)
                            .xpnseRoundedCorner()
                        }

                        PhotosPicker(
                            selection: $imagePicker.imageSelections,
                            maxSelectionCount: 1,
                            matching: .images
                        ) {
                            HStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title2)
                                Text("Select from Library")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .xpnseRoundedCorner()
                        }
                    }
                    .padding(.horizontal)
                    
                    // Loading State
                    if billScannerService.isScanning {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Analyzing bill...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Extracted Data Preview
                    if let extractedData = billScannerService.extractedTransaction {
                        ExtractedDataPreview(data: extractedData)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
//        .sheet(
//            isPresented: $showingCamera
//        ) {
//            ImagePicker(selectedImages: $selectedImages, sourceType: .camera)
//        }
        .onChange(of: imagePicker.uiImages) { image in
            if let image = image.first {
                Task {
                    await billScannerService.scanBill(from: image)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .alert("Error", isPresented: .constant(billScannerService.errorMessage != nil)) {
            Button("OK") {
                billScannerService.errorMessage = nil
            }
        } message: {
            Text(billScannerService.errorMessage ?? "")
        }
    }
}

