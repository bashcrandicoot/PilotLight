import AppKit

@MainActor
protocol StatusItemHosting: AnyObject {
    var menuStatusText: String { get }
    var canHideBorder: Bool { get }
    func hideBorderNow()
    func showTestBorder()
    func showQuickStart()
    func showSettings()
    func quitApp()
}

@MainActor
final class StatusItemController: NSObject {
    private weak var host: StatusItemHosting?
    private let item: NSStatusItem
    private let statusLine: NSMenuItem
    private let hideItem: NSMenuItem
    private let testItem: NSMenuItem
    private let quickStartItem: NSMenuItem
    private let settingsItem: NSMenuItem

    init(host: StatusItemHosting) {
        self.host = host
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusLine = NSMenuItem(title: "Border: Off", action: nil, keyEquivalent: "")
        hideItem = NSMenuItem(title: "Hide Border Now", action: #selector(hideNow(_:)), keyEquivalent: "")
        testItem = NSMenuItem(title: "Show Test Border for \(Int(Constants.testDuration))s", action: #selector(showTest(_:)), keyEquivalent: "")
        quickStartItem = NSMenuItem(title: "Quick Start…", action: #selector(showQuickStart(_:)), keyEquivalent: "")
        settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        super.init()

        if let button = item.button {
            button.image = Self.menuImage()
            button.imagePosition = .imageOnly
            button.toolTip = Constants.appName
        }

        statusLine.isEnabled = false
        hideItem.target = self
        testItem.target = self
        quickStartItem.target = self
        settingsItem.target = self

        // Label is exactly "Tip Jar": no ellipsis, no "Ko-fi".
        let tipJarItem = NSMenuItem(title: "Tip Jar", action: #selector(openTipJar(_:)), keyEquivalent: "")
        tipJarItem.target = self

        let quitItem = NSMenuItem(title: "Quit PilotLight", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        menu.addItem(hideItem)
        menu.addItem(testItem)
        menu.addItem(.separator())
        menu.addItem(quickStartItem)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(tipJarItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        item.menu = menu
        refresh()
    }

    /// Official Ember menu-bar template (black silhouette, eye cut-outs).
    /// The system inks it to match the menu bar; do not tint it yourself.
    private static func menuImage() -> NSImage {
        if let named = NSImage(named: "MenuIcon") {
            named.isTemplate = true
            return named
        }
        if let url = Bundle.main.url(forResource: "MenuIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        if let symbol = NSImage(systemSymbolName: "flame", accessibilityDescription: Constants.appName) {
            symbol.isTemplate = true
            symbol.size = NSSize(width: 16, height: 16)
            return symbol
        }
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.isTemplate = true
        return image
    }

    func refresh() {
        let text = host?.menuStatusText ?? "Off"
        statusLine.title = "Border: \(text)"
        hideItem.isEnabled = host?.canHideBorder ?? false
        if let button = item.button {
            let on = hideItem.isEnabled
            button.toolTip = on ? "PilotLight, border on" : "PilotLight, border off"
            button.setAccessibilityLabel(button.toolTip)
        }
    }

    @objc private func hideNow(_ sender: Any?) {
        host?.hideBorderNow()
    }

    @objc private func showTest(_ sender: Any?) {
        host?.showTestBorder()
    }

    @objc private func showQuickStart(_ sender: Any?) {
        // Wait until the status-item menu has closed so the panel can key.
        DispatchQueue.main.async { [weak self] in
            self?.host?.showQuickStart()
        }
    }

    @objc private func showSettings(_ sender: Any?) {
        DispatchQueue.main.async { [weak self] in
            self?.host?.showSettings()
        }
    }

    @objc private func openTipJar(_ sender: Any?) {
        NSWorkspace.shared.open(Constants.tipJarURL)
    }

    @objc private func quit(_ sender: Any?) {
        host?.quitApp()
    }
}
