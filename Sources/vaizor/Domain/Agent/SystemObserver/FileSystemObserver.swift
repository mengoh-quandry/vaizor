import Foundation

// MARK: - File System Observer
// Monitors folders for new files, downloads, and changes using FSEvents

@MainActor
class FileSystemObserver {
    weak var delegate: SystemObserverDelegate?

    private var isObserving = false
    private var eventStream: FSEventStreamRef?
    private var watchedPaths: [String] = []

    // Recent events for deduplication
    private var recentFileEvents: [String: Date] = [:]
    private let deduplicationWindow: TimeInterval = 2.0

    // Default paths to watch - computed lazily to avoid triggering permissions on init
    private static var defaultWatchPaths: [String] {
        [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
            // Note: Downloads requires explicit user permission - only add when user enables observation
        ]
    }

    init(delegate: SystemObserverDelegate?) {
        self.delegate = delegate
        // Start with empty paths - user must explicitly enable observation
        self.watchedPaths = []
    }

    /// Configure default watch paths when user enables observation
    func configureDefaultPaths(includeDownloads: Bool = false) {
        watchedPaths = Self.defaultWatchPaths
        if includeDownloads {
            let downloadsPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
            watchedPaths.append(downloadsPath)
        }
    }

    // MARK: - Configuration

    func addWatchPath(_ path: String) {
        guard !watchedPaths.contains(path) else { return }
        watchedPaths.append(path)

        // Restart if already observing
        if isObserving {
            stopObserving()
            startObserving()
        }
    }

    func removeWatchPath(_ path: String) {
        watchedPaths.removeAll { $0 == path }

        if isObserving {
            stopObserving()
            startObserving()
        }
    }

    // MARK: - Lifecycle

    func startObserving() {
        guard !isObserving else { return }
        guard !watchedPaths.isEmpty else {
            AppLogger.shared.log("FileSystemObserver: No paths to watch", level: .warning)
            return
        }

        AppLogger.shared.log("FileSystemObserver: Starting - watching \(watchedPaths.count) paths", level: .info)
        isObserving = true

        createEventStream()
    }

    func stopObserving() {
        guard isObserving else { return }

        AppLogger.shared.log("FileSystemObserver: Stopping", level: .info)
        isObserving = false

        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    // MARK: - FSEvents Setup

    private func createEventStream() {
        let pathsToWatch = watchedPaths as CFArray

        // Callback context
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        // Create the stream
        eventStream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,  // Latency in seconds
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        guard let stream = eventStream else {
            AppLogger.shared.log("FileSystemObserver: Failed to create event stream", level: .error)
            return
        }

        // Schedule on main run loop
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
    }

    // MARK: - Event Handling

    fileprivate func handleFSEvent(paths: [String], flags: [FSEventStreamEventFlags]) {
        for (index, path) in paths.enumerated() {
            let eventFlags = flags[index]

            // Skip if recently processed (deduplication)
            if let lastEvent = recentFileEvents[path],
               Date().timeIntervalSince(lastEvent) < deduplicationWindow {
                continue
            }
            recentFileEvents[path] = Date()

            // Determine event type
            let eventType = determineEventType(flags: eventFlags, path: path)

            // Skip uninteresting events
            guard let type = eventType else { continue }

            // Get file info
            let fileName = (path as NSString).lastPathComponent
            let directory = (path as NSString).deletingLastPathComponent

            // Build event
            let event = SystemEvent(
                type: type,
                timestamp: Date(),
                source: "FileSystemObserver",
                data: [
                    "path": path,
                    "fileName": fileName,
                    "directory": directory,
                    "isDownload": directory.contains("Downloads") ? "true" : "false"
                ]
            )

            // Emit on main thread
            Task { @MainActor in
                self.delegate?.emitEvent(event)
            }

            AppLogger.shared.log("FileSystemObserver: \(type.rawValue) - \(fileName)", level: .debug)
        }

        // Clean up old deduplication entries
        cleanupRecentEvents()
    }

    private func determineEventType(flags: FSEventStreamEventFlags, path: String) -> SystemEventType? {
        // Check for item created
        if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
            // Check if it's in Downloads
            if path.contains("Downloads") {
                return .downloadCompleted
            }
            return .fileCreated
        }

        // Check for item removed
        if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
            return .fileDeleted
        }

        // Check for item modified
        if flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 {
            return .fileModified
        }

        // Check for item renamed (could be move)
        if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 {
            // Treat rename as modification for now
            return .fileModified
        }

        return nil
    }

    private func cleanupRecentEvents() {
        let cutoff = Date().addingTimeInterval(-deduplicationWindow * 2)
        recentFileEvents = recentFileEvents.filter { $0.value > cutoff }
    }

    // MARK: - Query Methods

    /// Get list of recent files in watched directories
    func getRecentFiles(in directory: String? = nil, limit: Int = 10) -> [FileInfo] {
        let paths = directory.map { [$0] } ?? watchedPaths
        var files: [FileInfo] = []

        let fileManager = FileManager.default

        for path in paths {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { continue }

            for fileName in contents {
                let fullPath = (path as NSString).appendingPathComponent(fileName)

                guard let attributes = try? fileManager.attributesOfItem(atPath: fullPath) else { continue }

                let modDate = attributes[.modificationDate] as? Date ?? Date.distantPast
                let size = attributes[.size] as? Int ?? 0
                let isDirectory = (attributes[.type] as? FileAttributeType) == .typeDirectory

                files.append(FileInfo(
                    path: fullPath,
                    name: fileName,
                    modificationDate: modDate,
                    size: size,
                    isDirectory: isDirectory
                ))
            }
        }

        // Sort by modification date and limit
        return files
            .sorted { $0.modificationDate > $1.modificationDate }
            .prefix(limit)
            .map { $0 }
    }

    struct FileInfo {
        let path: String
        let name: String
        let modificationDate: Date
        let size: Int
        let isDirectory: Bool
    }
}

// MARK: - FSEvents Callback

private func fsEventCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }

    let observer = Unmanaged<FileSystemObserver>.fromOpaque(info).takeUnretainedValue()

    // Convert paths
    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

    // Convert flags to array
    var flags: [FSEventStreamEventFlags] = []
    for i in 0..<numEvents {
        flags.append(eventFlags[i])
    }

    // Handle on main thread
    Task { @MainActor in
        observer.handleFSEvent(paths: paths, flags: flags)
    }
}
