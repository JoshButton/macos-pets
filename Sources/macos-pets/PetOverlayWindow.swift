import AppKit
import Foundation
import MacOSPetsKit

/// A transparent, borderless window pinned above everything else on one display.
///
/// It sits at `.screenSaver` level so it stays visible over full-screen apps,
/// joins all Spaces, and can appear on the lock screen. Mouse events are
/// ignored by default so it never interferes with normal work; pass-through is
/// disabled only while the pointer is dragging the ball.
final class PetOverlayWindow: NSWindow {

    /// The display this window covers, in global screen coordinates.
    private let coveredDisplay: NSRect
    var displayFrame: NSRect { coveredDisplay }

    init(displayFrame: NSRect) {
        self.coveredDisplay = displayFrame
        super.init(
            contentRect: displayFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isMovable = false
        isMovableByWindowBackground = false
        level = .screenSaver
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]

        contentView = PetOverlayView(frame: CGRect(origin: .zero, size: displayFrame.size))
    }

    // Never steal focus from whatever the user is actually working in.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Draws pets and the ball for one display.
final class PetOverlayView: NSView {

    /// Supplies the current frame to draw. Set by the controller.
    var render: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        render?()
    }

    /// Top-left origin, matching the pixel sprites which are authored top-down.
    override var isFlipped: Bool { true }

    /// Transparent views shouldn't paint a background.
    override var isOpaque: Bool { false }
}