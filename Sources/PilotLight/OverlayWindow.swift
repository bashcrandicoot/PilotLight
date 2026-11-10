import AppKit

/// Transparent, click-through overlay that never becomes key or main.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    convenience init(screen: NSScreen) {
        self.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
            .transient
        ]
        isReleasedWhenClosed = false
        isRestorable = false
        animationBehavior = .none
        hidesOnDeactivate = false
        canHide = false
        tabbingMode = .disallowed
        title = Constants.appName
        identifier = NSUserInterfaceItemIdentifier("PilotLightOverlay")
    }
}
