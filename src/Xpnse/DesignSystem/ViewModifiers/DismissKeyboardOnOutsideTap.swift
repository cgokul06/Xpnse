//
//  DismissKeyboardOnOutsideTap.swift
//  Xpnse
//

import SwiftUI
import UIKit

struct DismissKeyboardOnOutsideTap: UIViewRepresentable {
    var isEnabled: Bool
    var onOutsideTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        context.coordinator.onOutsideTap = onOutsideTap
        context.coordinator.isEnabled = isEnabled
        return view
    }

    func updateUIView(_ uiView: HostView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onOutsideTap = onOutsideTap
        uiView.coordinator = context.coordinator
        context.coordinator.ensureGestureInstalled(for: uiView)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled = false
        var onOutsideTap: () -> Void = {}
        private var gesture: UITapGestureRecognizer?

        func ensureGestureInstalled(for view: UIView) {
            guard let window = view.window else { return }

            if gesture == nil {
                let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
                recognizer.cancelsTouchesInView = false
                recognizer.delegate = self
                gesture = recognizer
            }

            guard let gesture else { return }
            if gesture.view !== window {
                gesture.view?.removeGestureRecognizer(gesture)
                window.addGestureRecognizer(gesture)
            }
        }

        func uninstall() {
            if let gesture {
                gesture.view?.removeGestureRecognizer(gesture)
            }
            gesture = nil
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard isEnabled, recognizer.state == .ended else { return }
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
            onOutsideTap()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            guard isEnabled else { return false }

            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView {
                    return false
                }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        deinit {
            uninstall()
        }
    }

    final class HostView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                coordinator?.ensureGestureInstalled(for: self)
            } else {
                coordinator?.uninstall()
            }
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            nil
        }
    }
}

extension View {
    func dismissKeyboardOnOutsideTap(
        isEnabled: Bool,
        onOutsideTap: @escaping () -> Void
    ) -> some View {
        background(
            DismissKeyboardOnOutsideTap(
                isEnabled: isEnabled,
                onOutsideTap: onOutsideTap
            )
        )
    }
}
