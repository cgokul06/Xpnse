//
//  ImagePicker.swift
//  Xpnse
//
//  Created by Gokul C on 16/09/25.
//

import Combine
import PhotosUI
import SwiftUI

@MainActor
class ImagePicker: ObservableObject {
    @Published var images: [Image] = []        // For SwiftUI display
    @Published var uiImages: [UIImage] = []    // For business logic (scanner, saving, etc.)

    @Published var imageSelections: [PhotosPickerItem] = [] {
        didSet {
            Task {
                for selection in imageSelections {
                    await loadTransferable(from: selection)
                }
            }
        }
    }

    private func loadTransferable(from selection: PhotosPickerItem) async {
        do {
            if let data = try await selection.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.uiImages.append(uiImage)
                    self.images.append(Image(uiImage: uiImage))
                }
            }
        } catch {
            print("Error loading image: \(error.localizedDescription)")
        }
    }
}
