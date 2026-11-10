import AppKit

/// First-run walkthrough, and the Quick Start item in the menu bar.
/// Copy matches QUICKSTART.md so the two cannot drift.
@MainActor
final class WelcomeWindowController: NSWindowController, NSWindowDelegate {
    static let shared = WelcomeWindowController()

    static let windowSize = NSSize(width: 460, height: 380)
    static let agentInstruction = """
    Before you control my Mac, run `~/bin/pilotlight on`. During long work, run `~/bin/pilotlight ping` at least every 15 minutes. When you're done, run `~/bin/pilotlight off`, even if something failed. For a single command, you can wrap it instead: `~/bin/pilotlight run -- <command>`.
    """

    private enum Page: Int, CaseIterable {
        case welcome, howItWorks, tellYourBot, tryIt, makeItYours, thanks

        var isFirst: Bool { self == .welcome }
        var isLast: Bool { self == .thanks }
        var next: Page? { Page(rawValue: rawValue + 1) }
        var previous: Page? { Page(rawValue: rawValue - 1) }
    }

    private var page: Page = .welcome
    private var thanksEmber: PillBotView?
    private let pageHost = NSView()
    private let dots = PageDotsView()
    private let backButton = NSButton()
    private let nextButton = NSButton()
    private var copyButton: NSButton?
    private var copiedReset: DispatchWorkItem?

    private init() {
        let window = ClosableWindow(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = Constants.quickStartTitle
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = false
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        super.init(window: window)
        window.delegate = self
        window.contentView = buildChrome()
        window.setContentSize(Self.windowSize)
        showPage(.welcome, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// - Parameter firstLaunch: When true, the window is brought forward and the
    ///   app is activated — expected for a new user. A menu reopen shows the
    ///   window without activating the app over whatever the user was doing.
    func present(firstLaunch: Bool) {
        showPage(.welcome, animated: false)
        guard let window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        if firstLaunch {
            activateApp()
        }
    }

    func windowWillClose(_ notification: Notification) {
        thanksEmber?.stopWorking()
        thanksEmber = nil
        Preferences.welcomeSeen = true
    }

    // MARK: Chrome

    private func buildChrome() -> NSView {
        let root = NSView(frame: NSRect(origin: .zero, size: Self.windowSize))

        pageHost.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(pageHost)

        dots.count = Page.allCases.count
        dots.translatesAutoresizingMaskIntoConstraints = false
        dots.onSelect = { [weak self] index in
            guard let page = Page(rawValue: index) else { return }
            self?.showPage(page, animated: true)
        }
        root.addSubview(dots)

        let footer = buildFooter()
        root.addSubview(footer)

        NSLayoutConstraint.activate([
            pageHost.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            pageHost.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            pageHost.topAnchor.constraint(equalTo: root.topAnchor),
            pageHost.bottomAnchor.constraint(equalTo: dots.topAnchor, constant: -4),

            dots.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            dots.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -10),
            dots.heightAnchor.constraint(equalToConstant: 16),
            dots.widthAnchor.constraint(equalToConstant: 120),

            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 52)
        ])
        return root
    }

    private func buildFooter() -> NSView {
        let footer = NSView()
        footer.translatesAutoresizingMaskIntoConstraints = false

        let hairline = HairlineView()
        hairline.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(hairline)

        backButton.title = "Back"
        backButton.bezelStyle = .rounded
        backButton.setButtonType(.momentaryPushIn)
        backButton.controlSize = .regular
        backButton.target = self
        backButton.action = #selector(goBack)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(backButton)

        nextButton.title = "Next"
        nextButton.bezelStyle = .rounded
        nextButton.setButtonType(.momentaryPushIn)
        nextButton.controlSize = .regular
        nextButton.keyEquivalent = "\r"
        nextButton.target = self
        nextButton.action = #selector(goForward)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(nextButton)

        NSLayoutConstraint.activate([
            hairline.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            hairline.topAnchor.constraint(equalTo: footer.topAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 1),

            backButton.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 20),
            backButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor, constant: 1),

            nextButton.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -20),
            nextButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor, constant: 1)
        ])
        return footer
    }

    // MARK: Pages

    private func showPage(_ page: Page, animated: Bool) {
        self.page = page
        copiedReset?.cancel()
        copiedReset = nil
        thanksEmber?.stopWorking()
        thanksEmber = nil

        let next = makePage(page)
        next.translatesAutoresizingMaskIntoConstraints = false
        next.alphaValue = animated ? 0 : 1
        pageHost.subviews.forEach { $0.removeFromSuperview() }
        pageHost.addSubview(next)
        NSLayoutConstraint.activate([
            next.leadingAnchor.constraint(equalTo: pageHost.leadingAnchor),
            next.trailingAnchor.constraint(equalTo: pageHost.trailingAnchor),
            next.topAnchor.constraint(equalTo: pageHost.topAnchor),
            next.bottomAnchor.constraint(equalTo: pageHost.bottomAnchor)
        ])

        dots.selectedIndex = page.rawValue
        backButton.isEnabled = !page.isFirst
        backButton.alphaValue = page.isFirst ? 0.4 : 1
        nextButton.title = page.isLast ? "Done" : "Next"
        nextButton.keyEquivalent = "\r"
        thanksEmber?.startHappy()

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                next.animator().alphaValue = 1
            }
        }
    }

    private func makePage(_ page: Page) -> NSView {
        switch page {
        case .welcome: return welcomePage()
        case .howItWorks: return howItWorksPage()
        case .tellYourBot: return tellYourBotPage()
        case .tryIt: return tryItPage()
        case .makeItYours: return makeItYoursPage()
        case .thanks: return thanksPage()
        }
    }

    private func welcomePage() -> NSView {
        let ember = PillBotView()
        ember.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ember.widthAnchor.constraint(equalToConstant: 80),
            ember.heightAnchor.constraint(equalToConstant: 80)
        ])
        return stackedPage(
            hero: ember,
            title: "See when your Mac is busy with a bot.",
            body: "PilotLight draws a soft glow around your screen, plus a pill that reads “Grok is working”, while an agent is using your Mac. Clicks, scrolling and typing pass straight through it.",
            centered: true
        )
    }

    private func howItWorksPage() -> NSView {
        let demo = GlowDemoView()
        demo.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            demo.widthAnchor.constraint(equalToConstant: 220),
            demo.heightAnchor.constraint(equalToConstant: 112)
        ])
        return stackedPage(
            hero: demo,
            title: "How it works",
            body: "The border shows while a bot is working on your Mac. If the flag at ~/.grok-working isn’t touched for 20 minutes, PilotLight hides the border so a crashed agent can’t leave it stuck. Ping at least every 15 minutes on long jobs.",
            centered: true
        )
    }

    private func tellYourBotPage() -> NSView {
        let page = insetPage()
        let title = heading("Tell your bot")
        let intro = bodyLabel("PilotLight doesn’t detect agents on its own. Paste this into Grok, or any agent that can run commands on your Mac:")

        let box = AppearanceBox()
        box.translatesAutoresizingMaskIntoConstraints = false

        let instruction = bodyLabel(Self.agentInstruction)
        instruction.font = .systemFont(ofSize: 12)
        instruction.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(instruction)

        let copy = NSButton(title: "Copy", target: self, action: #selector(copyInstruction))
        copy.bezelStyle = .rounded
        copy.setButtonType(.momentaryPushIn)
        copy.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(copy)
        copyButton = copy

        NSLayoutConstraint.activate([
            instruction.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            instruction.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            instruction.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            copy.topAnchor.constraint(equalTo: instruction.bottomAnchor, constant: 8),
            copy.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            copy.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10)
        ])

        let stack = NSStackView(views: [title, intro, box])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(stack)
        pin(stack, to: page, top: 20, sides: 24, bottom: 8)
        box.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return page
    }

    private func tryItPage() -> NSView {
        let page = insetPage()
        let title = heading("Try it")
        let test = NSButton(title: "Show Test Border", target: self, action: #selector(showTestBorder))
        test.bezelStyle = .rounded
        test.setButtonType(.momentaryPushIn)
        test.translatesAutoresizingMaskIntoConstraints = false

        let hint = bodyLabel("The test preview lasts 5 seconds and doesn’t leave the flag behind. You can also use the command line:")
        hint.font = .systemFont(ofSize: 12.5)

        let commands = """
        ~/bin/pilotlight on        Show the border
        ~/bin/pilotlight status    on, off or stale
        ~/bin/pilotlight ping      Keep it alive during long work
        ~/bin/pilotlight off       Hide it, even after a failure
        ~/bin/pilotlight run --    Run a command, always turn it off
        """
        let box = AppearanceBox()
        box.translatesAutoresizingMaskIntoConstraints = false
        let code = bodyLabel(commands)
        code.font = .monospacedSystemFont(ofSize: 10.5, weight: .regular)
        code.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(code)
        NSLayoutConstraint.activate([
            code.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            code.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            code.topAnchor.constraint(equalTo: box.topAnchor, constant: 10),
            code.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -10)
        ])

        let stack = NSStackView(views: [title, test, hint, box])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(12, after: title)
        page.addSubview(stack)
        pin(stack, to: page, top: 18, sides: 24, bottom: 8)
        box.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return page
    }

    private func makeItYoursPage() -> NSView {
        let page = insetPage()
        let title = heading("Make it yours")
        let intro = bodyLabel("Style, color and intensity live in Settings. Pick a glow style, a color, and how strong it looks.")

        let swatches = SwatchRowView()
        swatches.translatesAutoresizingMaskIntoConstraints = false
        swatches.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let open = NSButton(title: "Open Settings", target: self, action: #selector(openSettings))
        open.bezelStyle = .rounded
        open.setButtonType(.momentaryPushIn)
        open.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [title, intro, swatches, open])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(16, after: swatches)
        page.addSubview(stack)
        pin(stack, to: page, top: 22, sides: 24, bottom: 8)
        swatches.setContentHuggingPriority(.required, for: .horizontal)
        return page
    }

    private func thanksPage() -> NSView {
        let page = insetPage()
        let ember = PillBotView()
        ember.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ember.widthAnchor.constraint(equalToConstant: 112),
            ember.heightAnchor.constraint(equalToConstant: 112)
        ])
        thanksEmber = ember

        let title = heading("Thanks for trying PilotLight!")
        title.alignment = .center
        let body = bodyLabel("It's free, and it's made by bashframes. Tips help keep it going.")
        body.alignment = .center

        let tip = NSButton(title: "Tip Jar", target: self, action: #selector(openTipJar))
        tip.bezelStyle = .rounded
        tip.setButtonType(.momentaryPushIn)
        tip.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [ember, title, body, tip])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(16, after: ember)
        stack.setCustomSpacing(16, after: body)
        page.addSubview(stack)
        pin(stack, to: page, top: 16, sides: 28, bottom: 8, verticallyCentered: true)
        title.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        body.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return page
    }

    private func stackedPage(hero: NSView, title: String, body: String, centered: Bool) -> NSView {

        let page = insetPage()
        let titleLabel = heading(title)
        titleLabel.alignment = centered ? .center : .left
        let body = bodyLabel(body)
        body.alignment = centered ? .center : .left
        let stack = NSStackView(views: [hero, titleLabel, body])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(16, after: hero)
        page.addSubview(stack)
        pin(stack, to: page, top: 18, sides: 28, bottom: 8, verticallyCentered: true)
        titleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        body.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return page
    }

    private func insetPage() -> NSView {
        let page = NSView()
        page.translatesAutoresizingMaskIntoConstraints = false
        return page
    }

    private func pin(_ view: NSView, to page: NSView, top: CGFloat, sides: CGFloat, bottom: CGFloat, verticallyCentered: Bool = false) {
        var constraints: [NSLayoutConstraint] = [
            view.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: sides),
            view.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -sides),
            view.topAnchor.constraint(greaterThanOrEqualTo: page.topAnchor, constant: top),
            view.bottomAnchor.constraint(lessThanOrEqualTo: page.bottomAnchor, constant: -bottom)
        ]
        if verticallyCentered {
            constraints.append(view.centerYAnchor.constraint(equalTo: page.centerYAnchor))
        } else {
            constraints.append(view.topAnchor.constraint(equalTo: page.topAnchor, constant: top))
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func heading(_ string: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: string)
        field.font = .systemFont(ofSize: 20, weight: .bold)
        field.textColor = .labelColor
        field.maximumNumberOfLines = 3
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    private func bodyLabel(_ string: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: string)
        field.font = .systemFont(ofSize: 13)
        field.textColor = .labelColor
        field.maximumNumberOfLines = 0
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    // MARK: Actions

    @objc private func goBack() {
        guard let previous = page.previous else { return }
        showPage(previous, animated: true)
    }

    @objc private func goForward() {
        if let next = page.next {
            showPage(next, animated: true)
        } else {
            Preferences.welcomeSeen = true
            window?.close()
        }
    }

    @objc private func copyInstruction() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.agentInstruction, forType: .string)
        copyButton?.title = "Copied"
        copiedReset?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.copyButton?.title = "Copy"
            self?.copiedReset = nil
        }
        copiedReset = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    @objc private func showTestBorder() {
        NotificationCenter.default.post(name: .previewGlowRequested, object: nil)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.present()
    }

    @objc private func openTipJar() {
        NSWorkspace.shared.open(Constants.tipJarURL)
    }
}

// MARK: - Page dots (Lodge-style progress, compact)

final class PageDotsView: NSView {
    var count: Int = 5 {
        didSet { needsDisplay = true }
    }
    var selectedIndex: Int = 0 {
        didSet { needsDisplay = true }
    }
    var onSelect: ((Int) -> Void)?

    override var intrinsicContentSize: NSSize { NSSize(width: 120, height: 16) }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let diameter: CGFloat = 7
        let spacing: CGFloat = 10
        let total = CGFloat(count) * diameter + CGFloat(max(0, count - 1)) * spacing
        var x = ((bounds.width - total) / 2).rounded()
        let y = ((bounds.height - diameter) / 2).rounded()
        for index in 0..<count {
            let rect = NSRect(x: x, y: y, width: diameter, height: diameter)
            if index == selectedIndex {
                NSColor.controlAccentColor.setFill()
            } else {
                NSColor.tertiaryLabelColor.setFill()
            }
            NSBezierPath(ovalIn: rect).fill()
            x += diameter + spacing
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let diameter: CGFloat = 7
        let spacing: CGFloat = 10
        let total = CGFloat(count) * diameter + CGFloat(max(0, count - 1)) * spacing
        let start = ((bounds.width - total) / 2).rounded()
        let index = Int(((point.x - start) / (diameter + spacing)).rounded(.down))
        guard (0..<count).contains(index) else { return }
        onSelect?(index)
    }

}

final class HairlineView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        applyColor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColor()
    }

    private func applyColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.separatorColor.cgColor
        }
    }
}

/// A tiny screen with a soft gold glow and the working pill — for the "How it works" page.
final class GlowDemoView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let inset: CGFloat = 10
        let screen = bounds.insetBy(dx: inset, dy: inset)
        let radius: CGFloat = 8

        // Soft gold bloom just inside the edge.
        let glow = NSBezierPath(roundedRect: screen, xRadius: radius, yRadius: radius)
        let color = NSColor(srgbHex: 0xFFD60A, alpha: 0.55)
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        context?.setShadow(offset: .zero, blur: 8, color: color.cgColor)
        color.setStroke()
        glow.lineWidth = 3
        glow.stroke()
        context?.restoreGState()

        NSColor(srgbRed: 0.18, green: 0.16, blue: 0.14, alpha: 1).setFill()
        NSBezierPath(roundedRect: screen, xRadius: radius, yRadius: radius).fill()
        NSColor(srgbHex: 0xFFD60A, alpha: 0.7).setStroke()
        let rim = NSBezierPath(roundedRect: screen.insetBy(dx: 3, dy: 3), xRadius: 6, yRadius: 6)
        rim.lineWidth = 1.5
        rim.stroke()

        // Mini working pill — gold rim, Ember, and a text sliver.
        let pillW: CGFloat = 88
        let pillH: CGFloat = 16
        let pill = NSRect(x: screen.midX - pillW / 2, y: screen.maxY - 24, width: pillW, height: pillH)
        NSColor(srgbRed: 0.12, green: 0.08, blue: 0.04, alpha: 0.95).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pillH / 2, yRadius: pillH / 2).fill()
        NSColor(srgbHex: 0xFFD60A, alpha: 0.7).setStroke()
        let pillStroke = NSBezierPath(roundedRect: pill.insetBy(dx: 0.5, dy: 0.5), xRadius: pillH / 2, yRadius: pillH / 2)
        pillStroke.lineWidth = 1
        pillStroke.stroke()
        NSColor(srgbHex: 0xE25C3A).setFill()
        let ember = NSRect(x: pill.minX + 5, y: pill.midY - 5, width: 10, height: 10)
        NSBezierPath(ovalIn: ember).fill()
        NSColor(srgbHex: 0xFFF8E7, alpha: 0.92).setFill()
        let bar = NSRect(x: ember.maxX + 3, y: pill.midY - 2, width: pill.maxX - ember.maxX - 11, height: 4)
        NSBezierPath(roundedRect: bar, xRadius: 2, yRadius: 2).fill()
    }
}

/// Display-only row of the six glow colors.
final class SwatchRowView: NSView {
    override var isOpaque: Bool { false }
    override var intrinsicContentSize: NSSize { NSSize(width: 3 + 18 * 6 + 10 * 5 + 3, height: 28) }

    override func draw(_ dirtyRect: NSRect) {
        let colors = GlowPreset.allCases.map(\.color)
        let diameter: CGFloat = 18
        let spacing: CGFloat = 10
        var x: CGFloat = 3
        let y = ((bounds.height - diameter) / 2).rounded()
        for (index, color) in colors.enumerated() {
            let rect = NSRect(x: x, y: y, width: diameter, height: diameter)
            if index == 0 {
                NSColor.labelColor.setStroke()
                let ring = NSBezierPath(ovalIn: rect.insetBy(dx: -3, dy: -3))
                ring.lineWidth = 1.5
                ring.stroke()
            }
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            if index == colors.count - 1 {
                NSColor.separatorColor.setStroke()
                let edge = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
                edge.lineWidth = 1
                edge.stroke()
            }
            x += diameter + spacing
        }
    }
}

/// A rounded well whose fill and border follow the current appearance.
final class AppearanceBox: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        applyColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    private func applyColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
    }
}
