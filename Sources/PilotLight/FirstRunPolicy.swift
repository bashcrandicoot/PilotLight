import Foundation

/// Decisions for first-run CLI install and login-item registration.
/// Pure logic — no windows, no file access — so it can be unit-tested
/// without touching the disk or AppKit.
enum CLIInstallDecision: Equatable {
    /// Bundled tool is missing, or there is nothing to do.
    case skip
    /// Copy the bundled CLI into ~/bin (missing or stale).
    case install
}

enum LoginItemStatus: Equatable {
    case enabled
    case requiresApproval
    case notRegistered
    case notFound
}

enum LoginItemAutoDecision: Equatable {
    case skipAlreadyEnabled
    case skipRequiresApproval
    case skipLegacyLaunchAgent
    case skipExistingUser
    case register
}

enum FirstRunPolicy {
    /// Install the CLI when a bundled copy exists and the destination is
    /// missing or does not match that copy. Never writes outside the policy:
    /// the installer itself is responsible for staying inside the home folder.
    static func cliDecision(hasBundled: Bool, isPresent: Bool, isCurrent: Bool) -> CLIInstallDecision {
        guard hasBundled else { return .skip }
        if isPresent && isCurrent { return .skip }
        return .install
    }

    /// Auto-register the login item only on a true first launch, and only
    /// when macOS has not already enabled it, asked for approval, or when a
    /// previously installed LaunchAgent already starts the app at login.
    /// `.requiresApproval` is never forced.
    static func loginAutoDecision(
        isFirstLaunch: Bool,
        status: LoginItemStatus,
        legacyLaunchAgentPresent: Bool
    ) -> LoginItemAutoDecision {
        if status == .enabled { return .skipAlreadyEnabled }
        if status == .requiresApproval { return .skipRequiresApproval }
        if legacyLaunchAgentPresent { return .skipLegacyLaunchAgent }
        if !isFirstLaunch { return .skipExistingUser }
        return .register
    }

    /// A Settings toggle that turns Open at Login on.
    /// Register only when the service is not already waiting for approval.
    static func loginUserEnableDecision(status: LoginItemStatus) -> LoginItemAutoDecision {
        if status == .enabled { return .skipAlreadyEnabled }
        if status == .requiresApproval { return .skipRequiresApproval }
        return .register
    }
}
