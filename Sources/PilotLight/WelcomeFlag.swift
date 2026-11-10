import Foundation

/// First-launch gate for the Quick Start walkthrough.
/// Pure flag logic — no windows, no file access — so it can be unit-tested
/// on any platform.
struct WelcomeFlag: Equatable {
    var seen: Bool

    init(seen: Bool = false) {
        self.seen = seen
    }

    /// Auto-present only when the walkthrough has never been shown.
    var shouldShowOnLaunch: Bool { !seen }

    /// Record that the window has been presented. Idempotent.
    mutating func markShown() {
        seen = true
    }
}
