import AppKit
import QuartzCore

final class PillView: NSView {
    private let background = CAGradientLayer()
    private let border = CALayer()
    private let highlight = CALayer()
    private let bot = PillBotView()
    private let label = NSTextField(labelWithString: Constants.message)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
    }

    private func commonInit() {
        wantsLayer = true
        layer?.masksToBounds = false

        background.startPoint = CGPoint(x: 0.5, y: 1)
        background.endPoint = CGPoint(x: 0.5, y: 0)
        layer?.insertSublayer(background, at: 0)

        border.backgroundColor = nil
        border.shadowOffset = .zero
        layer?.addSublayer(border)

        layer?.addSublayer(highlight)

        layer?.shadowOpacity = 1

        addSubview(bot)

        label.stringValue = Constants.message
        label.textColor = Palette.pillText
        label.backgroundColor = .clear
        label.isBordered = false
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.refusesFirstResponder = true
        label.alignment = .left
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byClipping
        label.preferredMaxLayoutWidth = 0
        if let cell = label.cell as? NSTextFieldCell {
            cell.wraps = false
            cell.isScrollable = false
            cell.truncatesLastVisibleLine = false
            cell.lineBreakMode = .byClipping
        }
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        applyFont()
        applyMetrics(metrics())
        addSubview(label)

        applyTint()

        setAccessibilityLabel(Constants.message)
        setAccessibilityRole(.staticText)

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(textSizeChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        center.addObserver(self, selector: #selector(appearanceChanged), name: .glowAppearanceDidChange, object: nil)
        let distributed = DistributedNotificationCenter.default()
        for name in [
            Notification.Name("AppleTextScalingChangedNotification"),
            Notification.Name("AppleInterfaceTextSizeChanged"),
            Notification.Name("NSFontSizeDidChangeNotification")
        ] {
            distributed.addObserver(self, selector: #selector(textSizeChanged), name: name, object: nil)
        }
    }

    static func preferredFont() -> NSFont {
        // NSFontMetrics is not in the current AppKit SDK. Scale our 13.5 pt
        // medium from the system callout size (12 pt at the default setting).
        let calloutSize = NSFont.preferredFont(forTextStyle: .callout).pointSize
        let size = 13.5 * max(0.5, calloutSize / 12)
        return NSFont.systemFont(ofSize: size, weight: .medium)
    }

    private func applyFont() {
        let font = Self.preferredFont()
        if label.font != font {
            label.font = font
        }
    }

    func metrics() -> PillMetrics {
        PillMetrics(fontSize: (label.font ?? Self.preferredFont()).pointSize)
    }

    private func labelSize() -> NSSize {
        let font = label.font ?? Self.preferredFont()
        return (Constants.message as NSString).size(withAttributes: [.font: font])
    }

    private func applyMetrics(_ metrics: PillMetrics) {
        border.borderWidth = metrics.borderWidth
        border.shadowRadius = metrics.haloRadius
        layer?.shadowRadius = metrics.dropShadowRadius
        layer?.shadowOffset = CGSize(width: 0, height: -metrics.dropShadowOffset)
        highlight.cornerRadius = metrics.highlightHeight / 2
    }

    /// Tint the rim and halo to the current glow color. The fill stays a
    /// dark, slightly tinted plate; Ember and the cream label do not change.
    private func applyTint() {
        let tint = Preferences.glowColor
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        (tint.usingColorSpace(.sRGB) ?? tint).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        border.borderColor = tint.withAlphaComponent(0.58).cgColor
        border.shadowColor = tint.withAlphaComponent(0.7).cgColor
        border.shadowOpacity = 0.55
        highlight.backgroundColor = NSColor(
            srgbRed: min(1, red + 0.15),
            green: min(1, green + 0.12),
            blue: min(1, blue + 0.08),
            alpha: 0.22
        ).cgColor
        // Dark plate with a hint of the tint so Blue/Pink don't sit on gold-brown.
        let top = NSColor(srgbRed: 0.10 + red * 0.08, green: 0.07 + green * 0.06, blue: 0.03 + blue * 0.05, alpha: 0.92)
        let bottom = NSColor(srgbRed: 0.06 + red * 0.05, green: 0.04 + green * 0.04, blue: 0.02 + blue * 0.03, alpha: 0.94)
        background.colors = [top.cgColor, bottom.cgColor]
        layer?.shadowColor = NSColor(srgbRed: red * 0.45, green: green * 0.28, blue: blue * 0.10, alpha: 0.42).cgColor
        needsDisplay = true
    }

    @objc private func appearanceChanged() {
        applyTint()
    }

    @objc private func textSizeChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.applyFont()
            self?.invalidateIntrinsicContentSize()
            self?.needsLayout = true
            self?.superview?.needsLayout = true
        }
    }

    override var isOpaque: Bool { false }

    /// Width and height scale with the label font, including Ember and padding.
    override var intrinsicContentSize: NSSize {
        metrics().size(forText: labelSize())
    }

    override func layout() {
        super.layout()
        applyFont()
        let metrics = metrics()
        applyMetrics(metrics)
        let b = bounds
        let radius = b.height / 2
        layer?.cornerRadius = radius
        background.cornerRadius = radius
        border.cornerRadius = radius
        background.frame = b
        border.frame = b
        highlight.frame = NSRect(
            x: metrics.highlightInset,
            y: b.height - metrics.highlightDrop,
            width: max(0, b.width - metrics.highlightInset * 2),
            height: metrics.highlightHeight
        )
        let iconY = (b.height - metrics.iconSize) / 2
        bot.frame = NSRect(
            x: metrics.leadingPad,
            y: iconY,
            width: metrics.iconSize,
            height: metrics.iconSize
        )
        let textSize = labelSize()
        let textX = metrics.leadingPad + metrics.iconSize + metrics.iconGap
        let textY = (b.height - textSize.height) / 2 - metrics.opticalShift
        label.frame = NSRect(x: textX, y: textY, width: ceil(textSize.width), height: ceil(textSize.height))
    }

    func setWorking(_ working: Bool) {
        if working {
            bot.startWorking()
        } else {
            bot.stopWorking()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
