//
//  AutoDeleteSwipeRail.swift
//  Geolocation_v1.0.0
//
//  A transparent full-screen UIViewRepresentable overlay that intercepts pan
//  gestures starting within a narrow left-edge "rail" zone (x < captureWidth).
//
//  Placing the gesture at this layer — outside the List/UITableView hierarchy —
//  eliminates competition with UITableView's internal UIPanGestureRecognizer,
//  making swipe-to-multi-delete reliable. Touches outside the capture zone are
//  passed through via a custom hitTest, so checkboxes and all other row
//  interactions work normally.

import SwiftUI
import UIKit

struct AutoDeleteSwipeRail: UIViewRepresentable {

    /// Width in points (from the screen leading edge) within which touches
    /// are captured. Set to cover the handle strip but not the checkboxes.
    var captureWidth: CGFloat

    var isEnabled: Bool
    var onDragChanged: (CGPoint) -> Void
    var onDragEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            captureWidth: captureWidth,
            isEnabled: isEnabled,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        )
    }

    func makeUIView(context: Context) -> RailView {
        let view = RailView(coordinator: context.coordinator)
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ uiView: RailView, context: Context) {
        context.coordinator.captureWidth = captureWidth
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onDragChanged = onDragChanged
        context.coordinator.onDragEnded = onDragEnded
    }

    // MARK: - RailView

    /// A transparent UIView that only claims hit-tests within the capture zone.
    /// Returning nil from hitTest for other zones lets touches fall through to
    /// the List and its rows as normal.
    class RailView: UIView {
        weak var coordinator: Coordinator?

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(frame: .zero)
            backgroundColor = .clear
            isUserInteractionEnabled = true
        }

        required init?(coder: NSCoder) { fatalError() }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let coordinator, coordinator.isEnabled else { return nil }
            return point.x < coordinator.captureWidth ? self : nil
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var captureWidth: CGFloat
        var isEnabled: Bool
        var onDragChanged: (CGPoint) -> Void
        var onDragEnded: () -> Void

        init(
            captureWidth: CGFloat,
            isEnabled: Bool,
            onDragChanged: @escaping (CGPoint) -> Void,
            onDragEnded: @escaping () -> Void
        ) {
            self.captureWidth = captureWidth
            self.isEnabled = isEnabled
            self.onDragChanged = onDragChanged
            self.onDragEnded = onDragEnded
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard isEnabled else { return }
            // Use window coordinates — matches geo.frame(in: .global) used for
            // storing checkbox frames.
            let location = recognizer.location(in: recognizer.view?.window)
            switch recognizer.state {
            case .began, .changed:
                onDragChanged(location)
            case .ended, .cancelled, .failed:
                onDragEnded()
            default:
                break
            }
        }

        // Don't share with the List's scroll recognizer — we want to own the gesture.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            return false
        }
    }
}
