import AppKit
import QuartzCore

/// Full-screen glow plus the top-center message pill.
///
/// Geometry is always static. Only opacity pulses. There is no rotating
/// gradient or spinning rectangle.
final class GlowBorderView: NSView {
    private let bloomLayer = CALayer()
    private let pill = PillView()
    private var lastSize: CGSize = .zero
    private var lastScale: CGFloat = 0
    private var lastCornerRadius: CGFloat = -1
    private var lastStyle: GlowStyle?
    private var lastPreset: GlowPreset?
    private var lastIntensity: CGFloat = -1
    private var lastLineThickness: CGFloat = -1
    private var animating = false
    private var animationEpoch: CFTimeInterval = 0

    var menuBarHeight: CGFloat = 24
    var cornerRadius: CGFloat = GlowSpec.builtinCornerRadius {
        didSet {
            if oldValue != cornerRadius {
                lastCornerRadius = -1
                needsLayout = true
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false

        bloomLayer.masksToBounds = true
        bloomLayer.contentsGravity = .resize
        layer?.addSublayer(bloomLayer)

        pill.setAccessibilityLabel(Constants.message)
        pill.setAccessibilityRole(.staticText)
        addSubview(pill)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: .glowAppearanceDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appearanceChanged() {
        lastSize = .zero
        needsLayout = true
    }

    @objc private func accessibilityChanged() {
        if animating {
            startAnimations(epoch: animationEpoch)
        }
    }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let style = Preferences.glowStyle
        let preset = Preferences.glowPreset
        let intensity = Preferences.glowIntensity
        let thickness = Preferences.lineThickness
        if bounds.size == lastSize,
           scale == lastScale,
           cornerRadius == lastCornerRadius,
           style == lastStyle,
           preset == lastPreset,
           intensity == lastIntensity,
           thickness == lastLineThickness {
            positionPill()
            return
        }
        lastSize = bounds.size
        lastScale = scale
        lastCornerRadius = cornerRadius
        lastStyle = style
        lastPreset = preset
        lastIntensity = intensity
        lastLineThickness = thickness
        updateLayers(scale: scale, style: style, preset: preset, intensity: intensity)
        positionPill()
        if animating {
            startAnimations(epoch: animationEpoch)
        }
    }

    func startAnimations(epoch: CFTimeInterval) {
        animating = true
        animationEpoch = epoch
        bloomLayer.removeAnimation(forKey: "pulse")
        bloomLayer.opacity = 1
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            pill.setWorking(false)
            return
        }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.84
        pulse.toValue = 1
        pulse.duration = Constants.pulseDuration
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.beginTime = epoch
        pulse.isRemovedOnCompletion = false
        bloomLayer.add(pulse, forKey: "pulse")
        pill.setWorking(true)
    }

    func stopAnimations() {
        animating = false
        bloomLayer.removeAllAnimations()
        bloomLayer.opacity = 1
        pill.setWorking(false)
    }

    private func updateLayers(
        scale: CGFloat,
        style: GlowStyle,
        preset: GlowPreset,
        intensity: CGFloat
    ) {
        let bounds = self.bounds
        bloomLayer.frame = bounds
        bloomLayer.contentsScale = scale
        bloomLayer.contents = renderGlowImage(
            size: bounds.size,
            scale: scale,
            radius: cornerRadius,
            style: style,
            preset: preset,
            intensity: intensity
        )
    }

    private func renderGlowImage(
        size: CGSize,
        scale: CGFloat,
        radius: CGFloat,
        style: GlowStyle,
        preset: GlowPreset,
        intensity: CGFloat
    ) -> CGImage? {
        let pixelWidth = Int((size.width * scale).rounded())
        let pixelHeight = Int((size.height * scale).rounded())
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.scaleBy(x: scale, y: scale)
        let screen = CGRect(origin: .zero, size: size)

        switch style {
        case .softGlow:
            drawSoftGlow(in: context, screen: screen, radius: radius, preset: preset, intensity: intensity)
        case .pilotLine:
            drawPilotLine(in: context, screen: screen, radius: radius, preset: preset, intensity: intensity)
        case .lamp:
            drawLamp(in: context, screen: screen, preset: preset, intensity: intensity)
        case .cornerLamps:
            drawCornerLamps(in: context, screen: screen, preset: preset, intensity: intensity)
        }

        return context.makeImage()
    }

    /// Deeper contours grow their corner radius so the bloom stays rounded
    /// instead of squaring off once the inset passes the screen radius.
    private func contourRadius(base: CGFloat, inset: CGFloat, in rect: CGRect) -> CGFloat {
        let grown = max(0, base + inset * 1.25)
        return min(grown, min(rect.width, rect.height) / 2)
    }

    private func drawBands(
        _ bands: [GlowSpec.Band],
        in context: CGContext,
        screen: CGRect,
        radius: CGFloat
    ) {
        for band in bands {
            let outerInset = min(band.outer, min(screen.width, screen.height) / 2)
            let innerInset = min(band.inner, min(screen.width, screen.height) / 2)
            guard innerInset > outerInset else { continue }
            let outerRect = screen.insetBy(dx: outerInset, dy: outerInset)
            let innerRect = screen.insetBy(dx: innerInset, dy: innerInset)
            guard outerRect.width > 0, outerRect.height > 0 else { continue }
            context.setFillColor(band.color.cgColor)
            context.beginPath()
            context.addPath(
                CGPath(
                    roundedRect: outerRect,
                    cornerWidth: contourRadius(base: radius, inset: outerInset, in: outerRect),
                    cornerHeight: contourRadius(base: radius, inset: outerInset, in: outerRect),
                    transform: nil
                )
            )
            if innerRect.width > 0, innerRect.height > 0 {
                context.addPath(
                    CGPath(
                        roundedRect: innerRect,
                        cornerWidth: contourRadius(base: radius, inset: innerInset, in: innerRect),
                        cornerHeight: contourRadius(base: radius, inset: innerInset, in: innerRect),
                        transform: nil
                    )
                )
            }
            context.fillPath(using: .evenOdd)
        }
    }

    private func drawSoftGlow(
        in context: CGContext,
        screen: CGRect,
        radius: CGFloat,
        preset: GlowPreset,
        intensity: CGFloat
    ) {
        let bands = GlowSpec.bands(preset: preset, intensity: intensity)
        drawBands(bands, in: context, screen: screen, radius: radius)
    }

    private func drawPilotLine(
        in context: CGContext,
        screen: CGRect,
        radius: CGFloat,
        preset: GlowPreset,
        intensity: CGFloat
    ) {
        // A single solid line, inset from the bezel so the gap stays clear.
        // The path sits on the stroke's centre, so add half the thickness to the pad.
        let thickness = Preferences.lineThickness
        let inset = Preferences.lineInset + thickness / 2
        let lineRect = screen.insetBy(dx: inset, dy: inset)
        guard lineRect.width > 0, lineRect.height > 0 else { return }
        // Corners stay concentric with the screen's rounded corners.
        let lineRadius = min(max(0, radius - inset), min(lineRect.width, lineRect.height) / 2)
        let path = CGPath(
            roundedRect: lineRect,
            cornerWidth: lineRadius,
            cornerHeight: lineRadius,
            transform: nil
        )
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let color = preset.color.usingColorSpace(.sRGB) ?? preset.color
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let strokeAlpha = min(1, max(0, intensity))
        context.saveGState()
        context.setShouldAntialias(true)
        // A very slight softness — not a bloom.
        context.setShadow(
            offset: .zero,
            blur: 1.1,
            color: CGColor(srgbRed: red, green: green, blue: blue, alpha: 0.28 * strokeAlpha)
        )
        context.setStrokeColor(CGColor(srgbRed: red, green: green, blue: blue, alpha: strokeAlpha))
        context.setLineWidth(thickness)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }

    private func drawLamp(
        in context: CGContext,
        screen: CGRect,
        preset: GlowPreset,
        intensity: CGFloat
    ) {
        let height: CGFloat = 150
        let lampRect = CGRect(
            x: screen.minX,
            y: screen.maxY - height,
            width: screen.width,
            height: height
        )
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        preset.ramp.core.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let mid = preset.ramp.mid
        var midR: CGFloat = 0, midG: CGFloat = 0, midB: CGFloat = 0, midA: CGFloat = 0
        mid.getRed(&midR, green: &midG, blue: &midB, alpha: &midA)

        let colors = [
            CGColor(srgbRed: red, green: green, blue: blue, alpha: min(1, 0.55 * intensity)),
            CGColor(srgbRed: midR, green: midG, blue: midB, alpha: min(1, 0.18 * intensity)),
            CGColor(srgbRed: midR, green: midG, blue: midB, alpha: 0)
        ] as CFArray
        let locations: [CGFloat] = [0, 0.45, 1]
        guard let gradient = CGGradient(colorsSpace: context.colorSpace, colors: colors, locations: locations) else {
            return
        }
        context.saveGState()
        // Horizontal falloff: brightest in the middle 60%.
        let fade = CGGradient(
            colorsSpace: context.colorSpace,
            colors: [
                CGColor(gray: 0, alpha: 0),
                CGColor(gray: 0, alpha: 1),
                CGColor(gray: 0, alpha: 1),
                CGColor(gray: 0, alpha: 0)
            ] as CFArray,
            locations: [0, 0.2, 0.8, 1]
        )
        if let fade {
            context.clip(to: lampRect)
            // Draw the color wash first, then use a destination-in fade.
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: lampRect.midX, y: lampRect.maxY),
                end: CGPoint(x: lampRect.midX, y: lampRect.minY),
                options: []
            )
            context.setBlendMode(.destinationIn)
            context.drawLinearGradient(
                fade,
                start: CGPoint(x: lampRect.minX, y: lampRect.midY),
                end: CGPoint(x: lampRect.maxX, y: lampRect.midY),
                options: []
            )
        } else {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: lampRect.midX, y: lampRect.maxY),
                end: CGPoint(x: lampRect.midX, y: lampRect.minY),
                options: []
            )
        }
        context.restoreGState()
    }

    private func drawCornerLamps(
        in context: CGContext,
        screen: CGRect,
        preset: GlowPreset,
        intensity: CGFloat
    ) {
        let radius: CGFloat = 170
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        preset.ramp.core.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let colors = [
            CGColor(srgbRed: red, green: green, blue: blue, alpha: min(1, 0.62 * intensity)),
            CGColor(srgbRed: red, green: green, blue: blue, alpha: 0)
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: context.colorSpace, colors: colors, locations: [0, 1]) else {
            return
        }
        let centers = [
            CGPoint(x: screen.minX, y: screen.maxY),
            CGPoint(x: screen.maxX, y: screen.maxY),
            CGPoint(x: screen.minX, y: screen.minY),
            CGPoint(x: screen.maxX, y: screen.minY)
        ]
        for center in centers {
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: []
            )
        }
    }

    private func positionPill() {
        let metrics = pill.metrics()
        let size = pill.intrinsicContentSize
        // The overlay itself is the full screen, so the host frame grows with
        // the display, not a fixed pill rect. Keep the body under the menu
        // bar; the halo may extend into that band but stays on-screen.
        let topInset = max(menuBarHeight, 24)
        let x = (bounds.width - size.width) / 2
        var y = bounds.height - topInset - metrics.topGap - size.height
        // If a very large accessibility size would run off the bottom, sit it
        // on the remaining usable band rather than clipping Ember or the halo.
        let lowest = metrics.haloExtent
        let highest = bounds.height - size.height - min(metrics.haloExtent, topInset)
        if highest >= lowest {
            y = min(max(y, lowest), highest)
        }
        pill.frame = NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
