import AppKit
import QuartzCore

/// Ember, the animated terracotta bun in the working-border pill.
///
/// Drawn from Brandy's art spec (union of ellipses, white capsule eyes). The 2.4 s loop is a bob or squash,
/// a blink, then a look left and right. The static cream robot is gone.
final class PillBotView: NSView {
    private var animating = false
    private var mood: EmberBot.Mood = .working
    private var elapsed: TimeInterval = 0
    private var frozenTime: TimeInterval = 0
    private var lastTick: TimeInterval = 0
    private var timer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        timer?.invalidate()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
    }

    override var isFlipped: Bool { true }

    override var isOpaque: Bool { false }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layer?.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    func startWorking() {
        start(mood: .working)
    }

    /// Cheerful hop used on the Quick Start thank-you page.
    func startHappy() {
        start(mood: .happy)
    }

    private func start(mood: EmberBot.Mood) {
        self.mood = mood
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            timer?.invalidate()
            timer = nil
            animating = false
            elapsed = 0
            // Mid-hop still pose, so Ember still looks glad when motion is off.
            frozenTime = (mood == .happy) ? EmberBot.happyStillTime : 0
            needsDisplay = true
            return
        }
        frozenTime = 0
        elapsed = 0
        lastTick = CACurrentMediaTime()
        if !animating {
            animating = true
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
            timer.tolerance = 1.0 / 120.0
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        needsDisplay = true
    }

    func stopWorking() {
        animating = false
        timer?.invalidate()
        timer = nil
        elapsed = 0
        frozenTime = 0
        mood = .working
        needsDisplay = true
    }

    private func tick() {
        let now = CACurrentMediaTime()
        elapsed += now - lastTick
        lastTick = now
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        EmberBot.draw(in: bounds, context: ctx, time: animating ? elapsed : frozenTime, mood: mood)
    }
}

/// Vector Ember (64×64 viewBox) plus the official 2.4 s animation.
enum EmberBot {
    static let viewBox: CGFloat = 64
    static let fill = Palette.ember
    static let eyeFill = Palette.emberEyes
    enum Mood {
        case working
        case happy
    }

    static let loopDuration: TimeInterval = 2.4
    static let closedEyeScale: CGFloat = 0.12
    /// Frozen happy pose (peak of the first hop) when Reduce Motion is on.
    static let happyStillTime: TimeInterval = 0.3

    // Body ellipses as (cx, cy, rx, ry) in viewBox units.
    static let lobes: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (20.0, 34.5, 16.2, 16.2),
        (44.0, 34.5, 16.2, 16.2),
        (32.0, 21.0, 15.2, 15.2),
        (32.0, 38.5, 21.5, 15.5)
    ]

    static let eyeCenters = [CGPoint(x: 25.0, y: 33.0), CGPoint(x: 39.0, y: 33.0)]
    static let eyeSize = CGSize(width: 7.4, height: 15.8)
    static let eyeTilt: CGFloat = 10 * CGFloat.pi / 180
    static let squashAnchor = CGPoint(x: 32.0, y: 54.0)

    struct Pose {
        var bobY: CGFloat
        var scaleX: CGFloat
        var scaleY: CGFloat
        var blinkY: CGFloat
        var lookX: CGFloat
        var lookY: CGFloat
        var tilt: CGFloat

        static func at(time t: TimeInterval, mood: Mood = .working) -> Pose {
            switch mood {
            case .working: return working(at: t)
            case .happy: return happy(at: t)
            }
        }

        private static func working(at t: TimeInterval) -> Pose {
            let tau = normalized(t)
            let phase = sin(2 * Double.pi * tau / 1.2)
            return Pose(
                bobY: -5.0 * CGFloat(phase),
                scaleX: 1 - 0.035 * CGFloat(phase),
                scaleY: 1 + 0.05 * CGFloat(phase),
                blinkY: blink(at: tau),
                lookX: look(at: tau),
                lookY: 0,
                tilt: 0
            )
        }

        /// Bigger upward hops with a rest between them, a little rock, and
        /// a double blink. Brand had no separate happy or waving pose.
        private static func happy(at t: TimeInterval) -> Pose {
            let tau = normalized(t)
            let wave = sin(2 * Double.pi * tau / 1.2)
            let hop = max(0, wave)
            return Pose(
                bobY: -8.0 * CGFloat(hop),
                scaleX: 1 - 0.05 * CGFloat(hop),
                scaleY: 1 + 0.08 * CGFloat(hop),
                blinkY: happyBlink(at: tau),
                lookX: 0,
                lookY: -2.0,
                tilt: CGFloat(6 * Double.pi / 180) * CGFloat(sin(2 * Double.pi * tau / EmberBot.loopDuration))
            )
        }

        private static func normalized(_ t: TimeInterval) -> TimeInterval {
            let loop = EmberBot.loopDuration
            var tau = t.truncatingRemainder(dividingBy: loop)
            if tau < 0 { tau += loop }
            return tau
        }

        private static func blink(at t: TimeInterval) -> CGFloat {
            if t < 0.86 { return 1 }
            if t < 0.92 { return lerp(1, EmberBot.closedEyeScale, from: 0.86, to: 0.92, t: t) }
            if t < 0.96 { return EmberBot.closedEyeScale }
            if t < 1.02 { return lerp(EmberBot.closedEyeScale, 1, from: 0.96, to: 1.02, t: t) }
            return 1
        }

        private static func happyBlink(at t: TimeInterval) -> CGFloat {
            blinkWindow(t, start: 0.50) ?? blinkWindow(t, start: 1.70) ?? 1
        }

        private static func blinkWindow(_ t: TimeInterval, start: TimeInterval) -> CGFloat? {
            let closeEnd = start + 0.06
            let holdEnd = start + 0.10
            let openEnd = start + 0.16
            if t < start || t >= openEnd { return nil }
            if t < closeEnd { return lerp(1, EmberBot.closedEyeScale, from: start, to: closeEnd, t: t) }
            if t < holdEnd { return EmberBot.closedEyeScale }
            return lerp(EmberBot.closedEyeScale, 1, from: holdEnd, to: openEnd, t: t)
        }

        private static func look(at t: TimeInterval) -> CGFloat {
            if t < 1.28 { return 0 }
            if t < 1.48 { return lerp(0, -8, from: 1.28, to: 1.48, t: t) }
            if t < 1.66 { return -8 }
            if t < 1.90 { return lerp(-8, 8, from: 1.66, to: 1.90, t: t) }
            if t < 2.10 { return 8 }
            if t < 2.34 { return lerp(8, 0, from: 2.10, to: 2.34, t: t) }
            return 0
        }

        /// Cosine in-out, `ease(u) = 0.5 - 0.5·cos(πu)`, then lerp from…to.
        private static func lerp(
            _ from: CGFloat, _ to: CGFloat,
            from start: TimeInterval, to end: TimeInterval,
            t: TimeInterval
        ) -> CGFloat {
            if t <= start { return from }
            if t >= end { return to }
            let u = (t - start) / (end - start)
            let eased = 0.5 - 0.5 * cos(Double.pi * u)
            return from + (to - from) * CGFloat(eased)
        }
    }

    static func draw(in rect: CGRect, context ctx: CGContext, time: TimeInterval, mood: Mood = .working) {
        guard rect.width > 0, rect.height > 0 else { return }
        let pose = Pose.at(time: time, mood: mood)
        // Happy hops go above the 64-unit viewBox; pad so they don't clip.
        let pad: CGFloat = (mood == .happy) ? 10 : 0
        let padded = viewBox + pad * 2
        let unit = min(rect.width, rect.height) / padded
        ctx.saveGState()
        ctx.translateBy(x: rect.midX - (padded * unit) / 2, y: rect.midY - (padded * unit) / 2)
        ctx.scaleBy(x: unit, y: unit)
        ctx.translateBy(x: pad, y: pad)

        // Bob / squash / tilt on #bot, anchored at the body bottom centre (32, 54).
        ctx.translateBy(x: 0, y: pose.bobY)
        ctx.translateBy(x: squashAnchor.x, y: squashAnchor.y)
        ctx.rotate(by: pose.tilt)
        ctx.scaleBy(x: pose.scaleX, y: pose.scaleY)
        ctx.translateBy(x: -squashAnchor.x, y: -squashAnchor.y)

        fill.setFill()
        for (cx, cy, rx, ry) in lobes {
            ctx.fillEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        }

        // Look on #eyes, then per-eye tilt and blink, then the capsule.
        ctx.translateBy(x: pose.lookX, y: pose.lookY)
        eyeFill.setFill()
        for center in eyeCenters {
            ctx.saveGState()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.scaleBy(x: 1, y: pose.blinkY)
            ctx.rotate(by: eyeTilt)
            ctx.translateBy(x: -center.x, y: -center.y)
            let rect = CGRect(
                x: center.x - eyeSize.width / 2,
                y: center.y - eyeSize.height / 2,
                width: eyeSize.width,
                height: eyeSize.height
            )
            let path = CGPath(
                roundedRect: rect,
                cornerWidth: eyeSize.width / 2,
                cornerHeight: eyeSize.width / 2,
                transform: nil
            )
            ctx.addPath(path)
            ctx.fillPath()
            ctx.restoreGState()
        }

        ctx.restoreGState()
    }
}
