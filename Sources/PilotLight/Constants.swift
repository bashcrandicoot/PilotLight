import AppKit

enum Constants {
    static let bundleID = "com.bashframes.pilotlight"
    static let appName = "PilotLight"
    static let message = "Grok is working"
    static let flagFileName = ".grok-working"
    static let staleInterval: TimeInterval = 20 * 60
    static let pollInterval: TimeInterval = 1
    static let fadeDuration: TimeInterval = 0.3
    static let testDuration: TimeInterval = 5
    static let pulseDuration: TimeInterval = 3.2
    static let quickStartTitle = "PilotLight Quick Start"
    /// Same Ko-fi page Lodge uses (`Support.tipJarURL` in Lodge).
    static let tipJarURL = URL(string: "https://ko-fi.com/bashframes")!

    static var flagURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(flagFileName)
    }
}

/// Working-pill layout. Every length is a multiple of the label's point size;
/// the numbers below are the approved measurements at 13.5 pt.
struct PillMetrics {
    static let designFontSize: CGFloat = 13.5
    static let designHeight: CGFloat = 36
    static let designIconSize: CGFloat = 26
    static let designLeadingPad: CGFloat = 9
    static let designIconGap: CGFloat = 9
    static let designTrailingPad: CGFloat = 16
    static let designVerticalPad: CGFloat = 10
    static let designTopGap: CGFloat = 11
    static let designBorderWidth: CGFloat = 1
    static let designHighlightInset: CGFloat = 14
    static let designHighlightHeight: CGFloat = 1
    static let designHighlightDrop: CGFloat = 1.25
    static let designHaloRadius: CGFloat = 14
    static let designDropShadowRadius: CGFloat = 12
    static let designDropShadowOffset: CGFloat = 3
    static let designOpticalShift: CGFloat = 0.5

    let fontSize: CGFloat

    init(fontSize: CGFloat) {
        self.fontSize = max(fontSize, 1)
    }

    var scale: CGFloat { fontSize / Self.designFontSize }

    var height: CGFloat { Self.designHeight * scale }
    var iconSize: CGFloat { Self.designIconSize * scale }
    var leadingPad: CGFloat { Self.designLeadingPad * scale }
    var iconGap: CGFloat { Self.designIconGap * scale }
    var trailingPad: CGFloat { Self.designTrailingPad * scale }
    var verticalPad: CGFloat { Self.designVerticalPad * scale }
    var topGap: CGFloat { Self.designTopGap * scale }
    var borderWidth: CGFloat { Self.designBorderWidth * scale }
    var highlightInset: CGFloat { Self.designHighlightInset * scale }
    var highlightHeight: CGFloat { Self.designHighlightHeight * scale }
    var highlightDrop: CGFloat { Self.designHighlightDrop * scale }
    var haloRadius: CGFloat { Self.designHaloRadius * scale }
    var dropShadowRadius: CGFloat { Self.designDropShadowRadius * scale }
    var dropShadowOffset: CGFloat { Self.designDropShadowOffset * scale }
    var opticalShift: CGFloat { Self.designOpticalShift * scale }

    /// Room around the body so the halo and Ember's bob are not clipped.
    var haloExtent: CGFloat { ceil(max(haloRadius, dropShadowRadius + dropShadowOffset) * 2) }

    func size(forText text: NSSize) -> NSSize {
        let contentHeight = max(iconSize, ceil(text.height)) + verticalPad
        return NSSize(
            width: leadingPad + iconSize + iconGap + ceil(text.width) + trailingPad,
            height: max(height, contentHeight)
        )
    }
}

enum Palette {
    static let gold = NSColor(srgbHex: 0xFFD60A)
    static let goldDeep = NSColor(srgbHex: 0xFFB800)
    static let goldLight = NSColor(srgbHex: 0xFFE56A)
    static let goldAmber = NSColor(srgbHex: 0xF5A400)
    static let goldStroke = NSColor(srgbHex: 0xC98900)

    static let pillTop = NSColor(srgbHex: 0x302006, alpha: 0.92)
    static let pillBottom = NSColor(srgbHex: 0x181004, alpha: 0.94)
    static let pillBorder = NSColor(srgbHex: 0xFFD60A, alpha: 0.58)
    static let pillText = NSColor(srgbHex: 0xFFF8E7)
    static let pillHighlight = NSColor(srgbHex: 0xFFF3C8, alpha: 0.22)

    static let ember = NSColor(srgbHex: 0xE25C3A)
    static let emberEyes = NSColor.white
}

/// One-click glow colors in Settings. Yellow is the default.
enum GlowPreset: String, CaseIterable {
    case yellow
    case amber
    case blue
    case green
    case pink
    case white

    var title: String {
        switch self {
        case .yellow: return "Yellow"
        case .amber: return "Amber"
        case .blue: return "Blue"
        case .green: return "Green"
        case .pink: return "Pink"
        case .white: return "White"
        }
    }

    var color: NSColor {
        switch self {
        case .yellow: return NSColor(srgbHex: 0xFFD60A)
        case .amber: return NSColor(srgbHex: 0xFF9F0A)
        case .blue: return NSColor(srgbHex: 0x0A84FF)
        case .green: return NSColor(srgbHex: 0x30D158)
        case .pink: return NSColor(srgbHex: 0xFF375F)
        case .white: return NSColor(srgbHex: 0xFFFFFF)
        }
    }

    static func matching(_ color: NSColor, tolerance: CGFloat = 0.04) -> GlowPreset {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        srgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        for preset in GlowPreset.allCases {
            var presetRed: CGFloat = 0, presetGreen: CGFloat = 0, presetBlue: CGFloat = 0, presetAlpha: CGFloat = 0
            preset.color.getRed(&presetRed, green: &presetGreen, blue: &presetBlue, alpha: &presetAlpha)
            if abs(red - presetRed) <= tolerance,
               abs(green - presetGreen) <= tolerance,
               abs(blue - presetBlue) <= tolerance {
                return preset
            }
        }
        return .yellow
    }

    /// Core / mid / outer colors for the Soft Glow ramp, so non-yellow
    /// presets keep the same depth as the default gold profile.
    var ramp: (core: NSColor, mid: NSColor, outer: NSColor) {
        switch self {
        case .yellow:
            return (NSColor(srgbHex: 0xFFD60A), NSColor(srgbHex: 0xFFB800), NSColor(srgbHex: 0xF5A400))
        case .amber:
            return (NSColor(srgbHex: 0xFF9F0A), NSColor(srgbHex: 0xFF7A00), NSColor(srgbHex: 0xE06000))
        case .blue:
            return (NSColor(srgbHex: 0x64D2FF), NSColor(srgbHex: 0x0A84FF), NSColor(srgbHex: 0x0040DD))
        case .green:
            return (NSColor(srgbHex: 0x63E6A0), NSColor(srgbHex: 0x30D158), NSColor(srgbHex: 0x0B8F3A))
        case .pink:
            return (NSColor(srgbHex: 0xFF6B8A), NSColor(srgbHex: 0xFF375F), NSColor(srgbHex: 0xD30F45))
        case .white:
            return (NSColor(srgbHex: 0xFFFFFF), NSColor(srgbHex: 0xE8E8ED), NSColor(srgbHex: 0xC7C7CC))
        }
    }
}

enum GlowStyle: String, CaseIterable {
    case softGlow
    case pilotLine
    case lamp
    case cornerLamps

    var title: String {
        switch self {
        case .softGlow: return "Soft Glow"
        case .pilotLine: return "Pilot Line"
        case .lamp: return "Lamp"
        case .cornerLamps: return "Corner Lamps"
        }
    }

    /// Short label for a segmented control.
    var shortTitle: String {
        switch self {
        case .softGlow: return "Soft Glow"
        case .pilotLine: return "Pilot Line"
        case .lamp: return "Lamp"
        case .cornerLamps: return "Corners"
        }
    }

    var blurb: String {
        switch self {
        case .softGlow: return "A soft bloom around the whole screen."
        case .pilotLine: return "A clean line around the screen, inset from the edge."
        case .lamp: return "A warm wash falling from the top, behind the pill."
        case .cornerLamps: return "Soft lights tucked into the four corners."
        }
    }
}

/// Soft yellow edge glow matching the approved mockup's inset box-shadows,
/// without a rotating gradient or a hard rectangular ring.
enum GlowSpec {
    static let builtinCornerRadius: CGFloat = 12
    static let externalCornerRadius: CGFloat = 10
    /// How far the faintest bloom reaches inward, in points.
    static let maxDistance: CGFloat = 80
    static let bandStep: CGFloat = 2

    struct Band {
        let outer: CGFloat
        let inner: CGFloat
        let color: NSColor
    }

    static func bands(
        preset: GlowPreset = .yellow,
        intensity: CGFloat = Preferences.defaultIntensity,
        maxDistance: CGFloat = GlowSpec.maxDistance
    ) -> [Band] {
        var result: [Band] = []
        var distance: CGFloat = 0
        while distance < maxDistance {
            let inner = distance + bandStep
            let base = color(at: distance + bandStep / 2, ramp: preset.ramp)
            let alpha = min(1, base.alphaComponent * intensity)
            if alpha >= 0.008 {
                result.append(Band(outer: distance, inner: inner, color: base.withAlphaComponent(alpha)))
            }
            distance = inner
        }
        return result
    }

    /// Approximates the mockup CSS:
    ///   inset 0 0 12px 3px rgba(255, 214, 10, 0.88)
    ///   inset 0 0 30px 9px rgba(255, 184, 0, 0.55)
    ///   inset 0 0 56px 16px rgba(245, 164, 0, 0.28)
    /// plus a little leftover outer-bloom at the very edge.
    private static func color(
        at distance: CGFloat,
        ramp: (core: NSColor, mid: NSColor, outer: NSColor)
    ) -> NSColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        func overlay(_ color: NSColor, sourceAlpha: CGFloat) {
            guard sourceAlpha > 0 else { return }
            let srgb = color.usingColorSpace(.sRGB) ?? color
            var sourceRed: CGFloat = 0, sourceGreen: CGFloat = 0, sourceBlue: CGFloat = 0, sourceA: CGFloat = 0
            srgb.getRed(&sourceRed, green: &sourceGreen, blue: &sourceBlue, alpha: &sourceA)
            let outAlpha = sourceAlpha + alpha * (1 - sourceAlpha)
            guard outAlpha > 0 else { return }
            red = (sourceRed * sourceAlpha + red * alpha * (1 - sourceAlpha)) / outAlpha
            green = (sourceGreen * sourceAlpha + green * alpha * (1 - sourceAlpha)) / outAlpha
            blue = (sourceBlue * sourceAlpha + blue * alpha * (1 - sourceAlpha)) / outAlpha
            alpha = outAlpha
        }

        func shadow(spread: CGFloat, blur: CGFloat, strength: CGFloat) -> CGFloat {
            if distance <= spread { return strength }
            if distance >= spread + blur { return 0 }
            let t = (distance - spread) / blur
            let smooth = t * t * (3 - 2 * t)
            return strength * (1 - smooth)
        }

        overlay(ramp.outer, sourceAlpha: shadow(spread: 16, blur: 56, strength: 0.28))
        overlay(ramp.mid, sourceAlpha: shadow(spread: 9, blur: 30, strength: 0.55))
        overlay(ramp.core, sourceAlpha: shadow(spread: 3, blur: 12, strength: 0.88))
        overlay(ramp.mid, sourceAlpha: shadow(spread: 0, blur: 6, strength: 0.22))
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

extension NSColor {
    convenience init(srgbHex hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}
