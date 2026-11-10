import AppKit

/// Titled window that closes on Escape. Fixed size, no zoom.
final class ClosableWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

func activateApp() {
    if #available(macOS 14, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Bring a titled panel above other apps. An LSUIElement accessory app
/// does not become key just from `makeKeyAndOrderFront`; activate first,
/// then order the window front regardless of who was active.
func bringPanelForward(_ window: NSWindow) {
    window.level = .normal
    activateApp()
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
}

/// Menu-bar Settings: style, one-click glow color, and intensity.
@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    static let contentWidth: CGFloat = 480
    static let margin: CGFloat = 20
    private static let autosaveName = "PilotLightSettings.v3"

    private var swatches: [GlowSwatchButton] = []
    private let styleControl = NSSegmentedControl()
    private let styleBlurb = NSTextField(labelWithString: "")
    private let slider = NSSlider()
    private let valueLabel = NSTextField(labelWithString: "")
    private let thicknessSlider = NSSlider()
    private let thicknessValue = NSTextField(labelWithString: "")
    private let thicknessSection = NSStackView()
    private let previewButton = NSButton(title: "Preview", target: nil, action: nil)
    private let resetButton = NSButton(title: "Reset", target: nil, action: nil)
    private let tipJarButton = NSButton(title: "Tip Jar", target: nil, action: nil)
    private let cliSwitch = NSButton(checkboxWithTitle: "Bot command (~/bin/pilotlight)", target: nil, action: nil)
    private let cliStatus = NSTextField(labelWithString: "")
    private let loginSwitch = NSButton(checkboxWithTitle: "Open at login", target: nil, action: nil)
    private let loginStatus = NSTextField(labelWithString: "")
    private let loginItemsButton = NSButton(title: "Open Login Items…", target: nil, action: nil)
    private var didCenterOnce = false
    private var previewDebounce: DispatchWorkItem?
    private var showingThickness = false

    private init() {
        let window = ClosableWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.contentWidth, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "PilotLight Settings"
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        super.init(window: window)
        window.contentView = buildContent()
        refresh()
        refitWindow()
        window.setFrameAutosaveName(Self.autosaveName)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(previewDidEnd),
            name: .previewGlowDidEnd,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        refresh()
        guard let window else { return }
        if !window.setFrameUsingName(Self.autosaveName) {
            if !didCenterOnce {
                window.center()
                didCenterOnce = true
            }
        }
        refitWindow()
        bringPanelForward(window)
    }

    private func buildContent() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: Self.margin, left: Self.margin, bottom: Self.margin, right: Self.margin)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.detachesHiddenViews = true

        let styleCaption = caption("Style")
        stack.addArrangedSubview(styleCaption)
        stack.setCustomSpacing(8, after: styleCaption)

        styleControl.segmentCount = GlowStyle.allCases.count
        styleControl.trackingMode = .selectOne
        styleControl.segmentStyle = .rounded
        styleControl.segmentDistribution = .fillEqually
        for (index, style) in GlowStyle.allCases.enumerated() {
            styleControl.setLabel(style.shortTitle, forSegment: index)
        }
        styleControl.target = self
        styleControl.action = #selector(styleChanged)
        styleControl.translatesAutoresizingMaskIntoConstraints = false
        styleControl.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(styleControl)
        stack.setCustomSpacing(6, after: styleControl)

        styleBlurb.font = .systemFont(ofSize: 11)
        styleBlurb.textColor = .secondaryLabelColor
        styleBlurb.lineBreakMode = .byWordWrapping
        styleBlurb.maximumNumberOfLines = 2
        styleBlurb.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(styleBlurb)

        let colorCaption = caption("Glow color")
        stack.addArrangedSubview(colorCaption)
        stack.setCustomSpacing(8, after: colorCaption)

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12
        row.distribution = .equalSpacing
        row.translatesAutoresizingMaskIntoConstraints = false
        row.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for preset in GlowPreset.allCases {
            let swatch = GlowSwatchButton(preset: preset)
            swatch.target = self
            swatch.action = #selector(swatchClicked(_:))
            swatches.append(swatch)
            row.addArrangedSubview(swatch)
        }
        stack.addArrangedSubview(row)

        // Line thickness — only visible for Pilot Line.
        thicknessSection.orientation = .vertical
        thicknessSection.alignment = .leading
        thicknessSection.spacing = 8
        thicknessSection.translatesAutoresizingMaskIntoConstraints = false
        thicknessSection.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let thicknessHeader = NSStackView()
        thicknessHeader.orientation = .horizontal
        thicknessHeader.alignment = .centerY
        thicknessHeader.distribution = .fill
        thicknessHeader.translatesAutoresizingMaskIntoConstraints = false
        let thicknessCaption = caption("Line thickness")
        thicknessValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        thicknessValue.textColor = .secondaryLabelColor
        thicknessValue.translatesAutoresizingMaskIntoConstraints = false
        thicknessValue.setContentHuggingPriority(.required, for: .horizontal)
        thicknessHeader.addArrangedSubview(thicknessCaption)
        thicknessHeader.addArrangedSubview(NSView())
        thicknessHeader.addArrangedSubview(thicknessValue)

        thicknessSlider.minValue = Double(Preferences.minLineThickness)
        thicknessSlider.maxValue = Double(Preferences.maxLineThickness)
        thicknessSlider.numberOfTickMarks = 8
        thicknessSlider.allowsTickMarkValuesOnly = true
        thicknessSlider.tickMarkPosition = .below
        thicknessSlider.isContinuous = true
        thicknessSlider.target = self
        thicknessSlider.action = #selector(thicknessChanged)
        thicknessSlider.translatesAutoresizingMaskIntoConstraints = false

        let thin = secondary("Thinner")
        let thick = secondary("Thicker")
        let thicknessLabels = NSStackView()
        thicknessLabels.orientation = .horizontal
        thicknessLabels.alignment = .centerY
        thicknessLabels.distribution = .equalSpacing
        thicknessLabels.translatesAutoresizingMaskIntoConstraints = false
        thicknessLabels.addArrangedSubview(thin)
        thicknessLabels.addArrangedSubview(NSView())
        thicknessLabels.addArrangedSubview(thick)

        thicknessSection.addArrangedSubview(thicknessHeader)
        thicknessSection.setCustomSpacing(8, after: thicknessHeader)
        thicknessSection.addArrangedSubview(thicknessSlider)
        thicknessSection.setCustomSpacing(4, after: thicknessSlider)
        thicknessSection.addArrangedSubview(thicknessLabels)
        stack.addArrangedSubview(thicknessSection)

        let intensityHeader = NSStackView()
        intensityHeader.orientation = .horizontal
        intensityHeader.alignment = .centerY
        intensityHeader.distribution = .fill
        intensityHeader.translatesAutoresizingMaskIntoConstraints = false
        let intensityCaption = caption("Glow intensity")
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        intensityHeader.addArrangedSubview(intensityCaption)
        intensityHeader.addArrangedSubview(NSView())
        intensityHeader.addArrangedSubview(valueLabel)
        stack.addArrangedSubview(intensityHeader)
        stack.setCustomSpacing(8, after: intensityHeader)

        slider.minValue = Double(Preferences.minIntensity)
        slider.maxValue = Double(Preferences.maxIntensity)
        slider.doubleValue = Double(Preferences.glowIntensity)
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(intensityChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(slider)
        stack.setCustomSpacing(4, after: slider)

        let intensityLabels = NSStackView()
        intensityLabels.orientation = .horizontal
        intensityLabels.alignment = .centerY
        intensityLabels.distribution = .equalSpacing
        intensityLabels.translatesAutoresizingMaskIntoConstraints = false
        intensityLabels.addArrangedSubview(secondary("Softer"))
        intensityLabels.addArrangedSubview(NSView())
        intensityLabels.addArrangedSubview(secondary("Stronger"))
        stack.addArrangedSubview(intensityLabels)

        let setupCaption = caption("Startup")
        stack.addArrangedSubview(setupCaption)
        stack.setCustomSpacing(8, after: setupCaption)

        loginSwitch.target = self
        loginSwitch.action = #selector(loginToggled)
        loginSwitch.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(loginSwitch)
        stack.setCustomSpacing(4, after: loginSwitch)

        loginStatus.font = .systemFont(ofSize: 11)
        loginStatus.textColor = .secondaryLabelColor
        loginStatus.lineBreakMode = .byWordWrapping
        loginStatus.maximumNumberOfLines = 2
        loginStatus.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(loginStatus)
        stack.setCustomSpacing(6, after: loginStatus)

        loginItemsButton.bezelStyle = .rounded
        loginItemsButton.setButtonType(.momentaryPushIn)
        loginItemsButton.target = self
        loginItemsButton.action = #selector(openLoginItems)
        loginItemsButton.translatesAutoresizingMaskIntoConstraints = false
        loginItemsButton.isHidden = true
        stack.addArrangedSubview(loginItemsButton)

        cliSwitch.target = self
        cliSwitch.action = #selector(cliToggled)
        cliSwitch.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(cliSwitch)
        stack.setCustomSpacing(4, after: cliSwitch)

        cliStatus.font = .systemFont(ofSize: 11)
        cliStatus.textColor = .secondaryLabelColor
        cliStatus.lineBreakMode = .byTruncatingMiddle
        cliStatus.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(cliStatus)

        tipJarButton.title = "Tip Jar"
        tipJarButton.target = self
        tipJarButton.action = #selector(openTipJar)
        tipJarButton.bezelStyle = .rounded
        tipJarButton.setButtonType(.momentaryPushIn)
        tipJarButton.translatesAutoresizingMaskIntoConstraints = false

        resetButton.title = "Reset"
        resetButton.target = self
        resetButton.action = #selector(resetClicked)
        resetButton.bezelStyle = .rounded
        resetButton.setButtonType(.momentaryPushIn)
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        previewButton.title = "Preview"
        previewButton.target = self
        previewButton.action = #selector(previewClicked)
        previewButton.bezelStyle = .rounded
        previewButton.setButtonType(.momentaryPushIn)
        previewButton.keyEquivalent = "\r"
        previewButton.translatesAutoresizingMaskIntoConstraints = false

        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.distribution = .fill
        buttons.translatesAutoresizingMaskIntoConstraints = false
        // Tip Jar + Reset on the left, Preview (default) on the right.
        // Tip Jar is a real push button, styled like Reset, with no symbol.
        let leading = NSStackView(views: [tipJarButton, resetButton])
        leading.orientation = .horizontal
        leading.alignment = .centerY
        leading.spacing = 12
        leading.translatesAutoresizingMaskIntoConstraints = false
        buttons.addArrangedSubview(leading)
        buttons.addArrangedSubview(NSView())
        buttons.addArrangedSubview(previewButton)
        stack.addArrangedSubview(buttons)

        let root = NSView(frame: .zero)
        root.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            styleControl.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -Self.margin * 2),
            styleBlurb.widthAnchor.constraint(equalTo: styleControl.widthAnchor),
            row.widthAnchor.constraint(equalTo: styleControl.widthAnchor),
            thicknessSection.widthAnchor.constraint(equalTo: styleControl.widthAnchor),
            thicknessHeader.widthAnchor.constraint(equalTo: thicknessSection.widthAnchor),
            thicknessSlider.widthAnchor.constraint(equalTo: thicknessSection.widthAnchor),
            thicknessLabels.widthAnchor.constraint(equalTo: thicknessSection.widthAnchor),
            intensityHeader.widthAnchor.constraint(equalTo: styleControl.widthAnchor),
            slider.widthAnchor.constraint(equalTo: styleControl.widthAnchor),
            intensityLabels.widthAnchor.constraint(equalTo: styleControl.widthAnchor),
            loginSwitch.widthAnchor.constraint(equalTo: styleControl.widthAnchor),
            loginStatus.widthAnchor.constraint(equalTo: styleControl.widthAnchor),
            cliSwitch.widthAnchor.constraint(equalTo: styleControl.widthAnchor),
            cliStatus.widthAnchor.constraint(equalTo: styleControl.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: styleControl.widthAnchor),

            root.widthAnchor.constraint(equalToConstant: Self.contentWidth)
        ])
        return root
    }

    private func caption(_ title: String) -> NSTextField {
        let field = NSTextField(labelWithString: title)
        field.font = .systemFont(ofSize: 13, weight: .medium)
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    private func secondary(_ title: String) -> NSTextField {
        let field = NSTextField(labelWithString: title)
        field.font = .systemFont(ofSize: 11)
        field.textColor = .secondaryLabelColor
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    /// Keep the top-left corner still while the content height changes
    /// (the thickness slider appearing or disappearing).
    private func refitWindow() {
        guard let window, let content = window.contentView else { return }
        content.layoutSubtreeIfNeeded()
        var fitting = content.fittingSize
        fitting.width = Self.contentWidth
        let newFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: fitting))
        var frame = window.frame
        frame.origin.y += frame.height - newFrame.height
        frame.size = newFrame.size
        window.setFrame(frame, display: true)
    }

    private func refresh() {
        let selected = Preferences.glowPreset
        for swatch in swatches {
            swatch.isChosen = (swatch.preset == selected)
        }
        if let index = GlowStyle.allCases.firstIndex(of: Preferences.glowStyle) {
            styleControl.selectedSegment = index
        }
        styleBlurb.stringValue = Preferences.glowStyle.blurb
        slider.doubleValue = Double(Preferences.glowIntensity)
        updateValueLabel()
        thicknessSlider.doubleValue = Double(Preferences.lineThickness)
        updateThicknessLabel()
        let showThickness = (Preferences.glowStyle == .pilotLine)
        thicknessSection.isHidden = !showThickness
        refreshSetupStatus()
        if showThickness != showingThickness {
            showingThickness = showThickness
            refitWindow()
        } else {
            refitWindow()
        }
    }

    private func refreshSetupStatus() {
        let cliOn = FirstRunSetup.cliIsInstalled
        cliSwitch.state = cliOn ? .on : .off
        if cliOn && FirstRunSetup.cliIsCurrent {
            cliStatus.stringValue = "Installed at ~/bin/pilotlight"
        } else if cliOn {
            cliStatus.stringValue = "Installed, but an update is available"
        } else {
            cliStatus.stringValue = "Not installed"
        }

        let status = FirstRunSetup.loginStatus()
        let legacy = FirstRunSetup.legacyLaunchAgentPresent
        loginSwitch.state = (status == .enabled || legacy) ? .on : .off
        loginItemsButton.isHidden = (status != .requiresApproval)
        switch status {
        case .enabled:
            loginStatus.stringValue = "On — PilotLight starts when you log in"
        case .requiresApproval:
            loginStatus.stringValue = "Allow PilotLight in System Settings → Login Items"
        case .notRegistered, .notFound:
            if legacy {
                loginStatus.stringValue = "On — a login item is already installed"
            } else {
                loginStatus.stringValue = "Off"
            }
        }
    }

    private func updateValueLabel() {
        let percent = Int((Preferences.glowIntensity * 100).rounded())
        valueLabel.stringValue = "\(percent)%"
    }

    private func updateThicknessLabel() {
        let points = Int(Preferences.lineThickness.rounded())
        thicknessValue.stringValue = "\(points) pt"
    }

    private func requestPreview(debounced: Bool) {
        previewButton.title = "Previewing…"
        let work = DispatchWorkItem { [weak self] in
            NotificationCenter.default.post(name: .previewGlowRequested, object: nil)
            self?.previewDebounce = nil
        }
        previewDebounce?.cancel()
        previewDebounce = work
        let delay: TimeInterval = debounced ? 0.25 : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    @objc private func previewDidEnd() {
        previewButton.title = "Preview"
    }

    @objc private func swatchClicked(_ sender: GlowSwatchButton) {
        Preferences.glowPreset = sender.preset
        refresh()
        requestPreview(debounced: true)
    }

    @objc private func styleChanged() {
        let index = styleControl.selectedSegment
        guard GlowStyle.allCases.indices.contains(index) else { return }
        Preferences.glowStyle = GlowStyle.allCases[index]
        refresh()
        requestPreview(debounced: true)
    }

    @objc private func intensityChanged() {
        Preferences.glowIntensity = CGFloat(slider.doubleValue)
        updateValueLabel()
        if NSApp.currentEvent?.type == .leftMouseUp {
            requestPreview(debounced: false)
        }
    }

    @objc private func thicknessChanged() {
        Preferences.lineThickness = CGFloat(thicknessSlider.doubleValue)
        updateThicknessLabel()
        if NSApp.currentEvent?.type == .leftMouseUp {
            requestPreview(debounced: false)
        }
    }

    @objc private func resetClicked() {
        Preferences.resetAppearance()
        refresh()
        requestPreview(debounced: true)
    }

    @objc private func previewClicked() {
        requestPreview(debounced: false)
    }

    @objc private func openTipJar() {
        NSWorkspace.shared.open(Constants.tipJarURL)
    }

    @objc private func cliToggled() {
        do {
            if cliSwitch.state == .on {
                try FirstRunSetup.installCLI()
            } else {
                try FirstRunSetup.uninstallCLI()
            }
        } catch {
            cliStatus.stringValue = "Could not update the bot command"
        }
        refreshSetupStatus()
        refitWindow()
    }

    @objc private func loginToggled() {
        if loginSwitch.state == .on {
            let decision = FirstRunPolicy.loginUserEnableDecision(status: FirstRunSetup.loginStatus())
            if decision == .register {
                FirstRunSetup.registerLoginItem()
            }
            // If approval is pending, leave it to System Settings — never force.
        } else {
            FirstRunSetup.unregisterLoginItem()
        }
        refreshSetupStatus()
        refitWindow()
    }

    @objc private func openLoginItems() {
        FirstRunSetup.openLoginItemsSettings()
    }
}

/// A small labeled color circle. The selected swatch draws a ring.
final class GlowSwatchButton: NSButton {
    let preset: GlowPreset
    var isChosen: Bool = false {
        didSet {
            needsDisplay = true
            setAccessibilityValue(isChosen ? 1 : 0)
        }
    }

    init(preset: GlowPreset) {
        self.preset = preset
        super.init(frame: NSRect(x: 0, y: 0, width: 44, height: 54))
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        title = ""
        imagePosition = .noImage
        toolTip = preset.title
        setButtonType(.momentaryChange)
        focusRingType = .exterior
        setAccessibilityLabel(preset.title)
        setAccessibilityRole(.radioButton)
        setAccessibilityValue(false)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 44, height: 54) }

    override var wantsUpdateLayer: Bool { false }

    private var circleRect: NSRect {
        let diameter: CGFloat = 22
        return NSRect(
            x: ((bounds.width - diameter) / 2).rounded(),
            y: (bounds.height - 18 - diameter).rounded(),
            width: diameter,
            height: diameter
        )
    }

    override func drawFocusRingMask() {
        NSBezierPath(ovalIn: circleRect.insetBy(dx: -4, dy: -4)).fill()
    }

    override var focusRingMaskBounds: NSRect { circleRect.insetBy(dx: -4, dy: -4) }

    override func draw(_ dirtyRect: NSRect) {
        let circle = circleRect
        if isChosen {
            let ring = circle.insetBy(dx: -4, dy: -4)
            NSColor.labelColor.setStroke()
            let ringPath = NSBezierPath(ovalIn: ring)
            ringPath.lineWidth = 2
            ringPath.stroke()
        }
        preset.color.setFill()
        NSBezierPath(ovalIn: circle).fill()
        if preset == .white {
            NSColor.separatorColor.setStroke()
            let edge = NSBezierPath(ovalIn: circle.insetBy(dx: 0.5, dy: 0.5))
            edge.lineWidth = 1
            edge.stroke()
        }

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style
        ]
        let title = NSAttributedString(string: preset.title, attributes: attrs)
        let titleSize = title.size()
        let titleRect = NSRect(x: 0, y: 0, width: bounds.width, height: titleSize.height)
        title.draw(in: titleRect)
    }
}
