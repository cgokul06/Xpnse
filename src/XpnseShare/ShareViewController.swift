//
//  ShareViewController.swift
//  XpnseShare
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await processSharedItems() }
    }

    private func processSharedItems() async {
        defer { finish() }

        if let imageData = await loadSharedImageData() {
            do {
                try SharedImageInboxStore.write(imageData)
                await openHostApp()
            } catch {
                return
            }
            return
        }

        guard let text = await loadSharedText() else { return }

        do {
            try SharedTextInboxStore.write(text)
        } catch {
            return
        }

        await openHostApp()
    }

    private func loadSharedImageData() async -> Data? {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments
        else {
            return nil
        }

        let imageTypes = [
            UTType.image.identifier,
            UTType.jpeg.identifier,
            UTType.png.identifier,
            UTType.heic.identifier
        ]

        for provider in attachments {
            for type in imageTypes where provider.hasItemConformingToTypeIdentifier(type) {
                if let data = await loadImageData(from: provider, type: type) {
                    return data
                }
            }
        }

        return nil
    }

    private func loadImageData(from provider: NSItemProvider, type: String) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                let data = Self.imageData(from: item)
                continuation.resume(returning: data)
            }
        }
    }

    private static func imageData(from item: NSSecureCoding?) -> Data? {
        if let image = item as? UIImage {
            return jpegOrPNGData(from: image)
        }
        if let data = item as? Data {
            if UIImage(data: data) != nil {
                return normalizedImageData(data)
            }
            return nil
        }
        if let url = item as? URL {
            guard let data = try? Data(contentsOf: url),
                  UIImage(data: data) != nil
            else {
                return nil
            }
            return normalizedImageData(data)
        }
        return nil
    }

    private static func normalizedImageData(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        return jpegOrPNGData(from: image) ?? data
    }

    private static func jpegOrPNGData(from image: UIImage) -> Data? {
        if let jpeg = image.jpegData(compressionQuality: 0.9) {
            return jpeg
        }
        return image.pngData()
    }

    private func loadSharedText() async -> String? {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments
        else {
            return nil
        }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = await loadString(from: provider, type: UTType.plainText.identifier) {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                if let text = await loadString(from: provider, type: UTType.text.identifier) {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
            }
        }

        if let subject = extensionContext?.inputItems
            .compactMap({ $0 as? NSExtensionItem })
            .compactMap(\.attributedContentText?.string)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !subject.isEmpty {
            return subject
        }

        return nil
    }

    private func loadString(from provider: NSItemProvider, type: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                if let string = item as? String {
                    continuation.resume(returning: string)
                } else if let data = item as? Data,
                          let string = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: string)
                } else if let url = item as? URL,
                          let string = try? String(contentsOf: url, encoding: .utf8) {
                    continuation.resume(returning: string)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    @MainActor
    private func openHostApp() async {
        let url = AppGroupConstants.shareInboxURL
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let completed = {
                continuation.resume()
            }

            var responder: UIResponder? = self
            while let current = responder {
                if let application = current as? UIApplication {
                    application.open(url, options: [:]) { _ in
                        completed()
                    }
                    return
                }
                // Selector openURL: for extension → host app
                if current.responds(to: Selector(("openURL:"))) {
                    current.perform(Selector(("openURL:")), with: url)
                    completed()
                    return
                }
                responder = current.next
            }

            extensionContext?.open(url) { _ in
                completed()
            }
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
