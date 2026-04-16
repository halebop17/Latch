import Foundation
import Combine

/// Wraps /usr/bin/caffeinate, the Apple-provided CLI tool for preventing Mac sleep.
///
/// caffeinate works by asserting IOKit power assertions on behalf of our process.
/// The -w flag ties its lifetime to ours: if the app crashes, caffeinate exits too.
final class CaffeineService: ObservableObject {

    @Published private(set) var isActive: Bool = false
    private var process: Process?

    // MARK: - Public API

    /// Start preventing sleep.
    /// - Parameters:
    ///   - seconds: Duration. Pass 0 for indefinite.
    ///   - allowDisplaySleep: If true, only system idle sleep is prevented (-i).
    ///                        If false, display sleep is also prevented (-di).
    func start(seconds: TimeInterval = 0, allowDisplaySleep: Bool = false) {
        // Kill any running process without publishing an isActive=false change,
        // which would race with the isActive=true we're about to set.
        killProcess()

        let caffeinate = Process()
        caffeinate.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")

        var args: [String] = allowDisplaySleep ? ["-i"] : ["-di"]

        if seconds > 0 {
            args += ["-t", String(Int(ceil(seconds)))]
        }

        // -w: caffeinate exits automatically when our process exits (crash safety)
        args += ["-w", String(ProcessInfo.processInfo.processIdentifier)]

        caffeinate.arguments = args

        // Fires on a background thread when caffeinate exits naturally (e.g. -t timer expired)
        caffeinate.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isActive = false
            }
        }

        do {
            try caffeinate.run()
            process = caffeinate
            isActive = true   // always called on main thread via AwakeManager
        } catch {
            NSLog("Rooster: Failed to launch caffeinate — %@", error.localizedDescription)
        }
    }

    /// Stop preventing sleep immediately.  Must be called on the main thread.
    func stop() {
        killProcess()
        isActive = false
    }

    // MARK: - Private

    /// Silently kills the caffeinate process without touching isActive.
    private func killProcess() {
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
    }
}
