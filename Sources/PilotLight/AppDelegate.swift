import AppKit
import os.log

@main
enum PilotLightMain {
    @MainActor
    static func main() {
        let delegate = AppDelegate()
        AppDelegate.retained = delegate
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, StatusItemHosting {
    static var retained: AppDelegate?

    private let log = Logger(subsystem: Constants.bundleID, category: "app")
    private var flagWatcher: FlagWatcher?
    private var overlay: OverlayController?
    private var statusItem: StatusItemController?
    private var flagState: FlagState = .off
    private var testUntil: Date?
    private var testTimer: Timer?

    var menuStatusText: String {
        if testUntil != nil {
            return "Test"
        }
        return flagState.statusWord
    }

    var canHideBorder: Bool {
        testUntil != nil || flagState.shouldShow
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Constants.bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if !others.isEmpty {
            log.info("Another PilotLight instance is already running; exiting")
            NSApp.terminate(nil)
            return
        }

        let overlay = OverlayController()
        self.overlay = overlay
        let watcher = FlagWatcher { [weak self] state in
            self?.flagDidChange(state)
        }
        self.flagWatcher = watcher
        statusItem = StatusItemController(host: self)
        NotificationCenter.default.addObserver(
            forName: .previewGlowRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showTestBorder()
            }
        }
        watcher.start()
        if !Preferences.welcomeSeen {
            WelcomeWindowController.shared.present(firstLaunch: true)
        }
        log.info("PilotLight ready")
    }

    func applicationWillTerminate(_ notification: Notification) {
        testTimer?.invalidate()
        flagWatcher?.stop()
        overlay?.stop()
    }

    func hideBorderNow() {
        cancelTest()
        flagWatcher?.removeFlag()
        overlay?.hide()
        statusItem?.refresh()
    }

    func showTestBorder() {
        testUntil = Date().addingTimeInterval(Constants.testDuration)
        overlay?.show()
        statusItem?.refresh()
        testTimer?.invalidate()
        testTimer = Timer.scheduledTimer(withTimeInterval: Constants.testDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.finishTestIfNeeded()
            }
        }
    }

    func showQuickStart() {
        // Menu reopen: start at page 1 without activating the app over the user.
        WelcomeWindowController.shared.present(firstLaunch: false)
    }

    func showSettings() {
        SettingsWindowController.shared.present()
    }

    func quitApp() {
        NSApp.terminate(nil)
    }

    private func flagDidChange(_ state: FlagState) {
        flagState = state
        if testUntil != nil {
            statusItem?.refresh()
            return
        }
        applyFlagState()
    }

    private func applyFlagState() {
        if flagState.shouldShow {
            overlay?.show()
        } else {
            overlay?.hide()
        }
        statusItem?.refresh()
    }

    private func finishTestIfNeeded() {
        guard let testUntil else { return }
        if Date() >= testUntil {
            cancelTest()
            applyFlagState()
        }
    }

    private func cancelTest() {
        let wasTesting = testUntil != nil
        testUntil = nil
        testTimer?.invalidate()
        testTimer = nil
        if wasTesting {
            NotificationCenter.default.post(name: .previewGlowDidEnd, object: nil)
        }
    }
}
