import Foundation
import Darwin

enum FlagState: Equatable {
    case off
    case on(age: TimeInterval)
    case stale(age: TimeInterval)

    var shouldShow: Bool {
        if case .on = self { return true }
        return false
    }

    var statusWord: String {
        switch self {
        case .off: return "Off"
        case .on: return "On"
        case .stale: return "Stale (hidden)"
        }
    }

    var kind: Kind {
        switch self {
        case .off: return .off
        case .on: return .on
        case .stale: return .stale
        }
    }

    enum Kind: Equatable {
        case off, on, stale
    }
}

/// Watches `~/.grok-working`. A 1-second poll covers stale mtime; a directory
/// source wakes the app immediately when the flag is created, removed, or touched.
@MainActor
final class FlagWatcher {
    private var timer: DispatchSourceTimer?
    private var directorySource: DispatchSourceFileSystemObject?
    private var directoryFD: Int32 = -1
    private var lastState: FlagState?
    private let onChange: (FlagState) -> Void

    init(onChange: @escaping (FlagState) -> Void) {
        self.onChange = onChange
    }

    func start() {
        stop()
        publish(force: true)

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Constants.pollInterval, repeating: Constants.pollInterval, leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.publish(force: false)
            }
        }
        timer.resume()
        self.timer = timer

        startDirectoryWatch()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        stopDirectoryWatch()
    }

    func currentState() -> FlagState {
        Self.readState()
    }

    func removeFlag() {
        let url = Constants.flagURL
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        publish(force: true)
    }

    private func startDirectoryWatch() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fd = open(home, O_EVTONLY)
        guard fd >= 0 else { return }
        directoryFD = fd
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend, .attrib, .link],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.publish(force: false)
            }
        }
        source.setCancelHandler {
            if fd >= 0 {
                close(fd)
            }
        }
        source.resume()
        directorySource = source
    }

    private func stopDirectoryWatch() {
        directorySource?.cancel()
        directorySource = nil
        directoryFD = -1
    }

    private func publish(force: Bool) {
        let state = Self.readState()
        if force || state.kind != lastState?.kind {
            lastState = state
            onChange(state)
        }
    }

    nonisolated static func readState() -> FlagState {
        let url = Constants.flagURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
            return .off
        }
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let mtime = values?.contentModificationDate ?? Date.distantPast
        let age = Date().timeIntervalSince(mtime)
        if age >= Constants.staleInterval {
            return .stale(age: age)
        }
        return .on(age: max(0, age))
    }
}
