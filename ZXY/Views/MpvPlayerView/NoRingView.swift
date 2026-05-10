import AppKit

class NoRingPlayerView: NSView {
    /// 1. Tell the system this view handles focus but wants no ring
    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }

    /// 2. The nuclear option: override the mask drawing so nothing is rendered
    override func drawFocusRingMask() {
        // Do nothing here
    }

    /// Ensure it can actually be focused for keyboard shortcuts
    override var acceptsFirstResponder: Bool {
        true
    }
}
