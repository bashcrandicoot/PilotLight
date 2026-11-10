import Foundation
import Darwin
import ServiceManagement
import os.log

/// Installs the `pilotlight` CLI into ~/bin and registers a login item.
/// All file writes stay inside the user's home directory. Never uses sudo.
enum FirstRunSetup {
    private static let log = Logger(subsystem: Constants.bundleID, category: "setup")
    private static let agentLabel = "com.bashframes.pilotlight"

    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    static var binDir: URL { home.appendingPathComponent("bin", isDirectory: true) }
    static var cliDest: URL { binDir.appendingPathComponent("pilotlight") }
    static var aliasDest: URL { binDir.appendingPathComponent("grok-border") }
    static var legacyAgent: URL {
        home.appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }

    static var bundledCLI: URL? {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/pilotlight")
        return FileManager.default.isReadableFile(atPath: url.path) ? url : nil
    }

    static func isInsideHome(_ url: URL) -> Bool {
        let root = home.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == root || path.hasPrefix(root + "/")
    }

    static var cliIsInstalled: Bool {
        FileManager.default.isReadableFile(atPath: cliDest.path)
    }

    static var cliIsCurrent: Bool {
        guard cliIsInstalled, let bundled = bundledCLI else { return false }
        return FileManager.default.contentsEqual(atPath: bundled.path, andPath: cliDest.path)
    }

    static var legacyLaunchAgentPresent: Bool {
        FileManager.default.fileExists(atPath: legacyAgent.path)
    }

    static func loginStatus() -> LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        case .notRegistered: return .notRegistered
        @unknown default: return .notRegistered
        }
    }

    static var loginIsOn: Bool {
        loginStatus() == .enabled || legacyLaunchAgentPresent
    }

    /// Called from applicationDidFinishLaunching. Silent: never opens
    /// System Settings or forces a login-item approval.
    static func applyOnLaunch(isFirstLaunch: Bool) {
        applyCLI()
        let decision = FirstRunPolicy.loginAutoDecision(
            isFirstLaunch: isFirstLaunch,
            status: loginStatus(),
            legacyLaunchAgentPresent: legacyLaunchAgentPresent
        )
        log.info("Login auto-setup: \(String(describing: decision), privacy: .public)")
        if decision == .register {
            registerLoginItem()
        }
    }

    static func applyCLI() {
        let decision = FirstRunPolicy.cliDecision(
            hasBundled: bundledCLI != nil,
            isPresent: cliIsInstalled,
            isCurrent: cliIsCurrent
        )
        log.info("CLI auto-setup: \(String(describing: decision), privacy: .public)")
        if decision == .install {
            do {
                try installCLI()
            } catch {
                log.error("CLI install failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func installCLI() throws {
        guard let bundled = bundledCLI else { return }
        guard isInsideHome(binDir), isInsideHome(cliDest), isInsideHome(aliasDest) else {
            throw SetupError.outsideHome
        }
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: cliDest.path) {
            try FileManager.default.removeItem(at: cliDest)
        }
        try FileManager.default.copyItem(at: bundled, to: cliDest)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cliDest.path)
        if FileManager.default.fileExists(atPath: aliasDest.path) {
            try FileManager.default.removeItem(at: aliasDest)
        }
        try FileManager.default.createSymbolicLink(at: aliasDest, withDestinationURL: cliDest)
        log.info("Installed CLI at \(self.cliDest.path, privacy: .public)")
    }

    static func uninstallCLI() throws {
        guard isInsideHome(cliDest), isInsideHome(aliasDest) else { throw SetupError.outsideHome }
        if FileManager.default.fileExists(atPath: aliasDest.path) {
            try FileManager.default.removeItem(at: aliasDest)
        }
        if FileManager.default.fileExists(atPath: cliDest.path) {
            try FileManager.default.removeItem(at: cliDest)
        }
    }

    static func registerLoginItem() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            log.error("Login item register failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func unregisterLoginItem() {
        do {
            let status = SMAppService.mainApp.status
            if status == .enabled || status == .requiresApproval || status == .notFound {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Login item unregister failed: \(error.localizedDescription, privacy: .public)")
        }
        removeLegacyLaunchAgent()
    }

    /// User-initiated only. Never called from auto-setup.
    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func removeLegacyLaunchAgent() {
        guard isInsideHome(legacyAgent) else { return }
        let uid = getuid()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["bootout", "gui/\(uid)/\(agentLabel)"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        if FileManager.default.fileExists(atPath: legacyAgent.path) {
            try? FileManager.default.removeItem(at: legacyAgent)
        }
    }

    enum SetupError: Error {
        case outsideHome
    }
}
