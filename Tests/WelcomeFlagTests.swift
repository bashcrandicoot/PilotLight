import Foundation

// Standalone checks for WelcomeFlag. Compile with WelcomeFlag.swift; no AppKit,
// no windows, no file reads.
@main
enum WelcomeFlagTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ message: String) {
        if !condition {
            failures += 1
            fputs("FAIL: \(message)\n", stderr)
        }
    }

    static func main() {
        var unseen = WelcomeFlag()
        expect(unseen.seen == false, "default is unseen")
        expect(unseen.shouldShowOnLaunch == true, "unseen flag should auto-show on launch")

        unseen.markShown()
        expect(unseen.seen == true, "markShown records that the window was presented")
        expect(unseen.shouldShowOnLaunch == false, "after show, it must not auto-open again")

        unseen.markShown()
        expect(unseen.seen == true, "markShown is idempotent")
        expect(unseen.shouldShowOnLaunch == false, "a second mark still does not auto-show")

        let alreadySeen = WelcomeFlag(seen: true)
        expect(alreadySeen.shouldShowOnLaunch == false, "a stored seen flag never auto-shows")
        expect(alreadySeen.seen == true, "menu can still present even when seen is true")

        var restored = WelcomeFlag(seen: false)
        expect(restored.shouldShowOnLaunch == true, "a fresh store auto-shows once")
        restored.markShown()
        let persisted = WelcomeFlag(seen: restored.seen)
        expect(persisted.shouldShowOnLaunch == false, "persisted seen value suppresses auto-show")

        if failures == 0 {
            print("WelcomeFlagTests: all passed")
        } else {
            fputs("WelcomeFlagTests: \(failures) failed\n", stderr)
            exit(1)
        }
    }
}
