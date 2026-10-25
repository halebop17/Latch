import Foundation

/// Keeps chosen external drives spinning by writing (and deleting) a tiny hidden file
/// on a timer.  Many external HDDs (e.g. LaCie) spin down on their own firmware timer
/// regardless of `pmset disksleep`, and a sleeping drive stalls Finder and Open/Save
/// dialogs for seconds while it spins back up.
final class DriveKeepAliveService {

    struct Volume: Identifiable, Hashable {
        let id: String      // volume UUID — stable across remounts and renames
        let name: String
        let url: URL
    }

    private static let fileName = ".latch-keepalive"

    private var timer: Timer?
    // File I/O off the main thread: touching a sleeping drive blocks until it spins up.
    private let ioQueue = DispatchQueue(label: "com.latch.driveKeepAlive", qos: .utility)

    var isRunning: Bool { timer != nil }

    /// Touches the chosen drives now, then every `AppSettings.driveKeepAliveIntervalMinutes`.
    func start() {
        stop()
        touchSelectedVolumes()
        let interval = TimeInterval(AppSettings.driveKeepAliveIntervalMinutes * 60)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.touchSelectedVolumes()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Writable, local, non-internal volumes — the candidates shown in Settings.
    static func externalVolumes() -> [Volume] {
        let keys: [URLResourceKey] = [.volumeUUIDStringKey, .volumeLocalizedNameKey,
                                      .volumeIsInternalKey, .volumeIsLocalKey,
                                      .volumeIsReadOnlyKey, .volumeIsBrowsableKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                         options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  let uuid = v.volumeUUIDString,
                  v.volumeIsInternal == false,
                  v.volumeIsLocal == true,
                  v.volumeIsReadOnly == false,
                  v.volumeIsBrowsable == true
            else { return nil }
            return Volume(id: uuid, name: v.volumeLocalizedName ?? url.lastPathComponent, url: url)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Private

    private func touchSelectedVolumes() {
        let selected = Set(AppSettings.driveKeepAliveVolumeIDs)
        // Unplugged drives simply aren't mounted, so they're skipped.
        let targets = Self.externalVolumes().filter { selected.contains($0.id) }
        guard !targets.isEmpty else { return }
        ioQueue.async {
            for volume in targets { Self.touch(volume.url) }
        }
    }

    /// Write + F_FULLFSYNC + delete.  A plain write may sit in the page cache and never
    /// reach the drive; F_FULLFSYNC forces it to the platters, which resets the drive's idle timer.
    private static func touch(_ volumeURL: URL) {
        let path = volumeURL.appendingPathComponent(fileName).path
        let fd = open(path, O_CREAT | O_WRONLY | O_TRUNC, 0o644)
        guard fd >= 0 else { return }
        var stamp = "\(Date().timeIntervalSince1970)\n"
        stamp.withUTF8 { _ = write(fd, $0.baseAddress, $0.count) }
        _ = fcntl(fd, F_FULLFSYNC)
        close(fd)
        unlink(path)
    }
}
