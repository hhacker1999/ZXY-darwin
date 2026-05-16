import AppKit
import SwiftUI

struct TrackpadScrollListener: NSViewRepresentable {
    var onSwipe: (NSEvent) -> Void

    func makeNSView(context _: Context) -> NSView {
        let view = TrackpadEventView()
        view.onSwipe = onSwipe
        return view
    }

    func updateNSView(_: NSView, context _: Context) {}
}

class TrackpadEventView: NSView {
    var onSwipe: ((NSEvent) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        onSwipe?(event)
        super.scrollWheel(with: event)
    }
}

extension View {
    func onTrackpadSwipe(onSwipe: @escaping (NSEvent) -> Void) -> some View {
        #if os(macOS)
            return overlay(TrackpadScrollListener(onSwipe: onSwipe))
        #else
            // In IOS Add drag gesture support
            return self
        #endif
    }
}
