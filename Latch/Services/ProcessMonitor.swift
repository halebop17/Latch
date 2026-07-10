import Foundation

/// Watches a single process and fires `onExit` when it terminates.
///
/// Backed by a kqueue DispatchSource (NOTE_EXIT), so there's no polling and no
/// special privileges are needed for processes owned by the current user — which
/// covers every app in the user's login session and any command they launched.
final class ProcessMonitor {

    private var source: DispatchSourceProcess?

    /// True while a process is being watched.
    var isWatching: Bool { source != nil }

    /// Start watching `pid`.  `onExit` is called once, on the main queue, when the
    /// process exits.  It is *not* called if you `cancel()` first.
    /// - Returns: false if the process isn't alive (or isn't ours to watch), in which
    ///   case there's nothing to wait for and no watch is started.
    @discardableResult
    func watch(pid: pid_t, onExit: @escaping () -> Void) -> Bool {
        cancel()

        // kill(pid, 0) probes existence without sending a signal: 0 means the
        // process is alive and ours; anything else means it's gone (or someone
        // else's, which kqueue couldn't watch anyway).
        guard pid > 0, kill(pid, 0) == 0 else { return false }

        let src = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        src.setEventHandler { [weak self] in
            self?.cancel()
            onExit()
        }
        source = src
        src.resume()
        return true
    }

    /// Stop watching without firing `onExit`.
    func cancel() {
        source?.setEventHandler(handler: nil)
        source?.cancel()
        source = nil
    }
}
