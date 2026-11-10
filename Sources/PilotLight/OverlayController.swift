import AppKit
import os.log
import QuartzCore

@MainActor
final class OverlayController: NSObject {
    private let log = Logger(subsystem: Constants.bundleID, category: "overlay")
    private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private var visible = false
    private var fadingOut = false
    private var showGeneration = 0
    private var animationEpoch: CFTimeInterval = 0

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged(_ notification: Notification) {
        syncScreens(preserveVisibility: true)
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        visible = false
        fadingOut = false
        for window in windows.values {
            window.orderOut(nil)
            (window.contentView as? GlowBorderView)?.stopAnimations()
            window.close()
        }
        windows.removeAll()
    }

    var isVisible: Bool { visible }

    func show() {
        let becameVisible = !visible
        showGeneration += 1
        fadingOut = false
        if !visible || windows.isEmpty {
            animationEpoch = CACurrentMediaTime()
        }
        visible = true
        syncScreens(preserveVisibility: true)
        if becameVisible {
            Self.announceWorking()
        }
        for window in windows.values {
            prepare(window)
            if window.alphaValue < 1 || !window.isVisible {
                if !window.isVisible {
                    window.alphaValue = 0
                    window.orderFrontRegardless()
                }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Constants.fadeDuration
                    window.animator().alphaValue = 1
                }
            }
        }
        log.debug("Border shown on \(self.windows.count, privacy: .public) screen(s)")
    }

    func hide() {
        guard visible || windows.contains(where: { $0.value.isVisible }) else { return }
        visible = false
        fadingOut = true
        showGeneration += 1
        let generation = showGeneration
        let pending = Array(windows.values)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.fadeDuration
            for window in pending {
                window.animator().alphaValue = 0
            }
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.showGeneration == generation else { return }
                self.fadingOut = false
                for window in self.windows.values {
                    window.orderOut(nil)
                    (window.contentView as? GlowBorderView)?.stopAnimations()
                }
            }
        }
        log.debug("Border hiding")
    }

    private func syncScreens(preserveVisibility: Bool) {
        let screens = NSScreen.screens
        var seen: Set<CGDirectDisplayID> = []
        for screen in screens {
            let displayID = Self.displayID(for: screen)
            seen.insert(displayID)
            let window = windows[displayID] ?? OverlayWindow(screen: screen)
            if windows[displayID] == nil {
                let view = GlowBorderView(frame: screen.frame)
                window.contentView = view
                windows[displayID] = window
            }
            window.setFrame(screen.frame, display: true)
            if let view = window.contentView as? GlowBorderView {
                view.menuBarHeight = Self.menuBarHeight(for: screen)
                view.cornerRadius = Self.cornerRadius(for: screen)
                view.needsLayout = true
            }
            if visible && preserveVisibility {
                prepare(window)
                if !window.isVisible {
                    window.alphaValue = fadingOut ? 0 : 1
                    if !fadingOut {
                        window.orderFrontRegardless()
                    }
                }
            }
        }
        for (id, window) in windows where !seen.contains(id) {
            window.orderOut(nil)
            window.close()
            windows.removeValue(forKey: id)
        }
    }

    private func prepare(_ window: OverlayWindow) {
        if let view = window.contentView as? GlowBorderView {
            view.startAnimations(epoch: animationEpoch)
        }
    }

    private static func announceWorking() {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: Constants.message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = screen.deviceDescription[key] as? NSNumber {
            return CGDirectDisplayID(number.uint32Value)
        }
        return 0
    }

    private static func cornerRadius(for screen: NSScreen) -> CGFloat {
        if CGDisplayIsBuiltin(displayID(for: screen)) != 0 {
            return GlowSpec.builtinCornerRadius
        }
        return GlowSpec.externalCornerRadius
    }

    private static func menuBarHeight(for screen: NSScreen) -> CGFloat {
        let fromVisible = screen.frame.maxY - screen.visibleFrame.maxY
        if fromVisible > 1 {
            return fromVisible
        }
        let inset = screen.safeAreaInsets.top
        if inset > 1 { return inset }
        return 24
    }
}
