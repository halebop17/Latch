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
    /// Main-thread only. A hung drive can block a pass indefinitely; skip ticks rather than pile them up.
    private var passInFlight = false

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

    /// Whether Latch has somewhere on this volume to write.  Time Machine drives, for one,
    /// can't be written to by anything but Time Machine.  Touches the drive — call off the main thread.
    static func canKeepAwake(_ volume: Volume) -> Bool {
        writableDirectory(on: volume.url) != nil
    }

    /// The APFS container (e.g. "disk11") holding this volume, or nil if it isn't APFS.
    static func apfsContainer(of volume: Volume) -> String? {
        diskutilInfo(volume.url.path)?["APFSContainerReference"] as? String
    }

    /// Adds a "Keep Awake" volume to an APFS container and returns its volume UUID.
    /// Writing to it keeps the whole physical disk spinning, without touching the other
    /// volumes; it shares the container's free space.
    static func addKeepAwakeVolume(to container: String) throws -> String {
        let (status, output) = diskutil(["apfs", "addVolume", container, "APFS", "Keep Awake"])
        // diskutil prints e.g. "Disk from APFS operation: disk11s2" on success.
        guard status == 0,
              let line = output.split(separator: "\n").first(where: { $0.hasPrefix("Disk from APFS operation:") }),
              let bsdName = line.split(separator: " ").last,
              let uuid = diskutilInfo(String(bsdName))?["VolumeUUID"] as? String
        else {
            let lines = output.split(separator: "\n")
            let reason = lines.first { $0.localizedCaseInsensitiveContains("error") } ?? lines.last
            throw DriveError(message: reason.map(String.init) ?? "diskutil couldn't add the volume.")
        }
        return uuid
    }

    struct DriveError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - Private

    private func touchSelectedVolumes() {
        let selected = Set(AppSettings.driveKeepAliveVolumeIDs)
        guard !selected.isEmpty, !passInFlight else { return }
        passInFlight = true
        ioQueue.async { [weak self] in
            // Unplugged drives simply aren't mounted, so they're skipped.
            for volume in Self.externalVolumes() where selected.contains(volume.id) {
                Self.touch(volume.url)
            }
            DispatchQueue.main.async { self?.passInFlight = false }
        }
    }

    /// Write + F_FULLFSYNC + delete.  A plain write may sit in the page cache and never
    /// reach the drive; F_FULLFSYNC forces it to the platters, which resets the drive's idle timer.
    private static func touch(_ volumeURL: URL) {
        guard let dir = writableDirectory(on: volumeURL) else { return }
        let path = dir.appendingPathComponent(fileName).path
        let fd = open(path, O_CREAT | O_WRONLY | O_TRUNC | O_NOFOLLOW, 0o644)
        guard fd >= 0 else { return }
        var stamp = "\(Date().timeIntervalSince1970)\n"
        stamp.withUTF8 { _ = write(fd, $0.baseAddress, $0.count) }
        _ = fcntl(fd, F_FULLFSYNC)
        close(fd)
        unlink(path)
    }

    /// The volume root if writable, else the first writable top-level folder — drives
    /// that respect ownership often have a root-owned root the user can't write to.
    private static func writableDirectory(on volumeURL: URL) -> URL? {
        if access(volumeURL.path, W_OK) == 0 { return volumeURL }
        let children = (try? FileManager.default.contentsOfDirectory(
            at: volumeURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
        return children.first { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                && access(url.path, W_OK) == 0
        }
    }

    private static func diskutilInfo(_ target: String) -> [String: Any]? {
        let (status, output) = diskutil(["info", "-plist", target])
        guard status == 0, let data = output.data(using: .utf8) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    /// Runs diskutil and returns its exit status and combined stdout/stderr.
    private static func diskutil(_ arguments: [String]) -> (Int32, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
