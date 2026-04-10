import Foundation
import CoreServices

/// Watches a directory tree for file changes using macOS FSEvents.
/// Reports changes categorized by type so the caller can react appropriately.
final class FileWatcher {
    enum ChangeKind {
        case css                       // style.css changed
        case markdown(Set<String>)     // .md files changed (set of absolute paths)
        case structure                 // files added or deleted
    }

    private var stream: FSEventStreamRef?
    private let callback: (ChangeKind) -> Void
    private let watchedDir: String
    private let outputDir: String

    /// Debounce: coalesce rapid changes into a single callback per kind.
    private var pendingCSS = false
    private var pendingStructure = false
    private var pendingMarkdownPaths: Set<String> = []
    private var debounceWork: DispatchWorkItem?

    init(directory: URL, outputDir: URL, onChange: @escaping (ChangeKind) -> Void) {
        self.watchedDir = directory.path
        self.outputDir = outputDir.path
        self.callback = onChange
    }

    func start() {
        let pathsToWatch = [watchedDir] as CFArray

        var context = FSEventStreamContext()
        // passRetained prevents use-after-free if the watcher is deallocated
        // while a callback is in flight. Released in stop().
        context.info = Unmanaged.passRetained(self).toOpaque()

        guard let stream = FSEventStreamCreate(
            nil,
            FileWatcher.eventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,  // latency — coalesce events within 300ms
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }

        self.stream = stream
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
    }

    func stop() {
        debounceWork?.cancel()
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        // Balance the passRetained in start()
        Unmanaged.passUnretained(self).release()
        self.stream = nil
    }

    deinit { stop() }

    // MARK: - FSEvents callback

    private static let eventCallback: FSEventStreamCallback = {
        _, clientCallBackInfo, numEvents, eventPaths, eventFlags, _ in

        guard let info = clientCallBackInfo else { return }
        let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()

        guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
        let flags = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))

        for i in 0..<numEvents {
            let path = paths[i]
            let flag = Int(flags[i])

            // Only watch files we care about — skip everything else
            if path.hasPrefix(watcher.outputDir) { continue }

            let filename = (path as NSString).lastPathComponent

            if path.hasSuffix(".css") {
                watcher.pendingCSS = true
            } else if path.hasSuffix(".md") {
                let isRemoved = (flag & kFSEventStreamEventFlagItemRemoved) != 0
                let isCreated = (flag & kFSEventStreamEventFlagItemCreated) != 0
                let isRenamed = (flag & kFSEventStreamEventFlagItemRenamed) != 0
                if isRemoved || isCreated || isRenamed {
                    watcher.pendingStructure = true
                }
                watcher.pendingMarkdownPaths.insert(path)
            } else if ["build.js", "app.js", "graph.js", "map.html"].contains(filename) {
                watcher.pendingStructure = true
            } else {
                continue
            }
        }

        // Debounce: coalesce rapid changes, fire once after 200ms of quiet
        watcher.debounceWork?.cancel()
        let hasCSS = watcher.pendingCSS
        let hasStructure = watcher.pendingStructure
        let mdPaths = watcher.pendingMarkdownPaths

        let work = DispatchWorkItem {
            watcher.pendingCSS = false
            watcher.pendingStructure = false
            watcher.pendingMarkdownPaths.removeAll()

            // Structure changes are the most disruptive — handle first
            if hasStructure {
                watcher.callback(.structure)
            } else {
                if hasCSS { watcher.callback(.css) }
                if !mdPaths.isEmpty { watcher.callback(.markdown(mdPaths)) }
            }
        }
        watcher.debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}
