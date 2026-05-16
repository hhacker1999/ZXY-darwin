import AppKit
import SwiftUI

struct TrackpadScrollListener: NSViewRepresentable {
    var onSwipe: (NSEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipe: onSwipe)
    }

    func makeNSView(context: Context) -> NSView {
        let view = TrackpadEventView()
        context.coordinator.view = view
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_: NSView, context: Context) {
        context.coordinator.onSwipe = onSwipe
    }

    static func dismantleNSView(_: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    class Coordinator {
        var onSwipe: (NSEvent) -> Void
        weak var view: NSView?
        private var monitor: Any?

        init(onSwipe: @escaping (NSEvent) -> Void) {
            self.onSwipe = onSwipe
        }

        func installMonitor() {
            // Use a local event monitor so scroll events are *observed*
            // without being consumed and without requiring our NSView
            // to win AppKit hit‑testing (it doesn't, see `hitTest`).
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
                [weak self] event in
                guard
                    let self = self,
                    let view = self.view,
                    let window = view.window,
                    event.window == window
                else {
                    return event
                }
                let pointInView = view.convert(event.locationInWindow, from: nil)
                if view.bounds.contains(pointInView) {
                    self.onSwipe(event)
                }
                return event
            }
        }

        func removeMonitor() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit { removeMonitor() }
    }
}

/// A click‑through NSView used purely to measure a frame inside the
/// SwiftUI hierarchy. Mouse / tap events pass through to the views below
/// so callers can still attach `onTapGesture` etc.; scroll‑wheel events
/// are picked up via an `NSEvent.addLocalMonitorForEvents` monitor in
/// `TrackpadScrollListener.Coordinator`.
class TrackpadEventView: NSView {
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}

extension View {
    func onTrackpadSwipe(onSwipe: @escaping (NSEvent) -> Void) -> some View {
        #if os(macOS)
            return overlay(TrackpadScrollListener(onSwipe: onSwipe))
        #else
            return self
        #endif
    }
}
