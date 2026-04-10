import Foundation

/// A node in the file tree — either a folder (with children) or a file.
final class FileNode: Identifiable {
    let id: String
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]?

    init(url: URL, isDirectory: Bool, children: [FileNode]? = nil) {
        self.id = url.path
        self.name = url.lastPathComponent
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
    }

    var isMarkdown: Bool {
        !isDirectory && url.pathExtension.lowercased() == "md"
    }

    var isCode: Bool {
        guard !isDirectory else { return false }
        let ext = url.pathExtension.lowercased()
        return ["css", "js", "json", "html"].contains(ext)
    }
}

/// Scans one level of a directory. Folders get an empty children array
/// (so OutlineGroup shows the disclosure triangle) but aren't recursively
/// scanned until the user expands them.
func scanOneLevel(at root: URL) -> [FileNode] {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }

    let sorted = contents.sorted {
        $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
    }

    // Folders first, then files — with custom sort order
    let topFolders: [String] = ["wiki"]
    let bottomFolders: [String] = ["raw", "site", "sources"]
    let pinnedFiles: [String] = ["AGENTS.md", "CLAUDE.md"]

    let folders = sorted.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    let allowedExtensions: Set<String> = ["md", "css", "js", "json", "html"]
    let files = sorted.filter {
        (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true
            && allowedExtensions.contains($0.pathExtension.lowercased())
            && !$0.lastPathComponent.hasSuffix(".min.js")
    }

    // Sort folders: topFolders first (in order), then alphabetical middle, then bottomFolders last (in order)
    let sortedFolders = folders.sorted { a, b in
        let aName = a.lastPathComponent
        let bName = b.lastPathComponent
        let aTop = topFolders.firstIndex(of: aName)
        let bTop = topFolders.firstIndex(of: bName)
        let aBot = bottomFolders.firstIndex(of: aName)
        let bBot = bottomFolders.firstIndex(of: bName)

        // Both in top group
        if let ai = aTop, let bi = bTop { return ai < bi }
        // a is top, b is not
        if aTop != nil { return true }
        // b is top, a is not
        if bTop != nil { return false }
        // Both in bottom group
        if let ai = aBot, let bi = bBot { return ai < bi }
        // a is bottom, b is not
        if aBot != nil { return false }
        // b is bottom, a is not
        if bBot != nil { return true }
        // Both in middle — alphabetical
        return aName.localizedCaseInsensitiveCompare(bName) == .orderedAscending
    }

    // Sort files: pinned first (in order), then alphabetical
    let sortedFiles = files.sorted { a, b in
        let aName = a.lastPathComponent
        let bName = b.lastPathComponent
        let aPin = pinnedFiles.firstIndex(of: aName)
        let bPin = pinnedFiles.firstIndex(of: bName)

        if let ai = aPin, let bi = bPin { return ai < bi }
        if aPin != nil { return true }
        if bPin != nil { return false }
        return aName.localizedCaseInsensitiveCompare(bName) == .orderedAscending
    }

    let folderNodes = sortedFolders.map { url in
        // Empty children array = expandable, but not yet scanned
        FileNode(url: url, isDirectory: true, children: [])
    }
    let fileNodes = sortedFiles.map { url in
        FileNode(url: url, isDirectory: false)
    }

    return folderNodes + fileNodes
}

/// Populates a folder node's children by scanning one level deeper.
func expandNode(_ node: FileNode) {
    guard node.isDirectory else { return }
    node.children = scanOneLevel(at: node.url)
}
