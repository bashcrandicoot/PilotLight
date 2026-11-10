import Foundation

// Standalone checks for FirstRunPolicy. Compile with FirstRunPolicy.swift;
// no AppKit, no windows, no file reads from the repo or the home folder.
@main
enum FirstRunPolicyTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ message: String) {
        if !condition {
            failures += 1
            fputs("FAIL: \(message)\n", stderr)
        }
    }

    static func main() {
        expect(FirstRunPolicy.cliDecision(hasBundled: false, isPresent: false, isCurrent: false) == .skip,
               "no bundled CLI means skip")
        expect(FirstRunPolicy.cliDecision(hasBundled: true, isPresent: true, isCurrent: true) == .skip,
               "present and current CLI is skipped")
        expect(FirstRunPolicy.cliDecision(hasBundled: true, isPresent: false, isCurrent: false) == .install,
               "missing CLI is installed")
        expect(FirstRunPolicy.cliDecision(hasBundled: true, isPresent: true, isCurrent: false) == .install,
               "stale CLI is replaced")

        expect(
            FirstRunPolicy.loginAutoDecision(isFirstLaunch: true, status: .notRegistered, legacyLaunchAgentPresent: false) == .register,
            "first launch with no login item registers"
        )
        expect(
            FirstRunPolicy.loginAutoDecision(isFirstLaunch: true, status: .notFound, legacyLaunchAgentPresent: false) == .register,
            "first launch with notFound registers"
        )
        expect(
            FirstRunPolicy.loginAutoDecision(isFirstLaunch: true, status: .enabled, legacyLaunchAgentPresent: false) == .skipAlreadyEnabled,
            "already enabled is skipped even on first launch"
        )
        expect(
            FirstRunPolicy.loginAutoDecision(isFirstLaunch: true, status: .requiresApproval, legacyLaunchAgentPresent: false) == .skipRequiresApproval,
            "requiresApproval is never forced on first launch"
        )
        expect(
            FirstRunPolicy.loginAutoDecision(isFirstLaunch: true, status: .notRegistered, legacyLaunchAgentPresent: true) == .skipLegacyLaunchAgent,
            "an existing LaunchAgent is left alone"
        )
        expect(
            FirstRunPolicy.loginAutoDecision(isFirstLaunch: false, status: .notRegistered, legacyLaunchAgentPresent: false) == .skipExistingUser,
            "existing users (welcomeSeen) do not auto-register"
        )
        expect(
            FirstRunPolicy.loginAutoDecision(isFirstLaunch: false, status: .enabled, legacyLaunchAgentPresent: false) == .skipAlreadyEnabled,
            "enabled wins over existing-user skip"
        )
        expect(
            FirstRunPolicy.loginUserEnableDecision(status: .notRegistered) == .register,
            "a Settings toggle on an unregistered item registers"
        )
        expect(
            FirstRunPolicy.loginUserEnableDecision(status: .requiresApproval) == .skipRequiresApproval,
            "a Settings toggle does not force a pending approval"
        )
        expect(
            FirstRunPolicy.loginUserEnableDecision(status: .enabled) == .skipAlreadyEnabled,
            "a Settings toggle on an already-enabled item is a no-op"
        )

        if failures == 0 {
            print("FirstRunPolicyTests: all passed")
        } else {
            fputs("FirstRunPolicyTests: \(failures) failed\n", stderr)
            exit(1)
        }
    }
}
