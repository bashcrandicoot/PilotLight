import AppKit

extension Notification.Name {
    static let glowAppearanceDidChange = Notification.Name("PilotLightGlowAppearanceDidChange")
    static let previewGlowRequested = Notification.Name("PilotLightPreviewGlowRequested")
    static let previewGlowDidEnd = Notification.Name("PilotLightPreviewGlowDidEnd")
}

enum Preferences {
    static let glowColorKey = "glowColor"
    static let glowPresetKey = "glowPreset"
    static let glowStyleKey = "glowStyle"
    static let glowIntensityKey = "glowIntensity"
    static let lineThicknessKey = "lineThickness"
    static let welcomeSeenKey = "welcomeSeen"

    static let defaultIntensity: CGFloat = 0.55
    static let minIntensity: CGFloat = 0.25
    static let maxIntensity: CGFloat = 1
    static let defaultLineThickness: CGFloat = 3
    static let minLineThickness: CGFloat = 1
    static let maxLineThickness: CGFloat = 8
    /// Gap between the Pilot Line and the screen edge.
    static let lineInset: CGFloat = 6
    static let defaultColor = Palette.gold
    static let defaultPreset: GlowPreset = .yellow
    static let defaultStyle: GlowStyle = .softGlow

    private static var defaults: UserDefaults { .standard }

    static var glowIntensity: CGFloat {
        get {
            guard defaults.object(forKey: glowIntensityKey) != nil else {
                return defaultIntensity
            }
            let value = CGFloat(defaults.double(forKey: glowIntensityKey))
            return min(maxIntensity, max(minIntensity, value))
        }
        set {
            let clamped = min(maxIntensity, max(minIntensity, newValue))
            defaults.set(Double(clamped), forKey: glowIntensityKey)
            notifyAppearance()
        }
    }

    static var glowPreset: GlowPreset {
        get {
            if let raw = defaults.string(forKey: glowPresetKey),
               let preset = GlowPreset(rawValue: raw) {
                return preset
            }
            // One-time migration from the retired NSColor well archive.
            if let data = defaults.data(forKey: glowColorKey),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                let preset = GlowPreset.matching(color)
                defaults.set(preset.rawValue, forKey: glowPresetKey)
                defaults.removeObject(forKey: glowColorKey)
                return preset
            }
            return defaultPreset
        }
        set {
            defaults.set(newValue.rawValue, forKey: glowPresetKey)
            defaults.removeObject(forKey: glowColorKey)
            notifyAppearance()
        }
    }

    static var glowColor: NSColor {
        get { glowPreset.color }
        set { glowPreset = GlowPreset.matching(newValue) }
    }

    static var lineThickness: CGFloat {
        get {
            guard defaults.object(forKey: lineThicknessKey) != nil else {
                return defaultLineThickness
            }
            let value = CGFloat(defaults.double(forKey: lineThicknessKey))
            return min(maxLineThickness, max(minLineThickness, value))
        }
        set {
            let clamped = min(maxLineThickness, max(minLineThickness, newValue))
            defaults.set(Double(clamped), forKey: lineThicknessKey)
            notifyAppearance()
        }
    }

    static var glowStyle: GlowStyle {
        get {
            if let raw = defaults.string(forKey: glowStyleKey),
               let style = GlowStyle(rawValue: raw) {
                return style
            }
            return defaultStyle
        }
        set {
            defaults.set(newValue.rawValue, forKey: glowStyleKey)
            notifyAppearance()
        }
    }

    static func resetAppearance() {
        glowPreset = defaultPreset
        glowStyle = defaultStyle
        glowIntensity = defaultIntensity
        lineThickness = defaultLineThickness
    }

    private static func notifyAppearance() {
        NotificationCenter.default.post(name: .glowAppearanceDidChange, object: nil)
    }

    static var welcomeSeen: Bool {
        get { defaults.bool(forKey: welcomeSeenKey) }
        set { defaults.set(newValue, forKey: welcomeSeenKey) }
    }
}
