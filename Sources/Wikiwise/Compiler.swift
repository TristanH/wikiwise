import Foundation
import JavaScriptCore

/// Thin Swift wrapper that loads build.js into JavaScriptCore and
/// injects native file I/O functions. The actual compilation logic
/// lives entirely in JavaScript.
final class Compiler {
    private let jsContext: JSContext
    let sourceDir: URL
    let outputDir: URL

    var outputPath: String { outputDir.path }

    init(sourceDir: URL) {
        self.sourceDir = sourceDir
        // Use site/out/ if the wiki has site/build.js (scaffolded wiki),
        // otherwise fall back to wiki-site/ for legacy/plain folders.
        let siteOut = sourceDir.appendingPathComponent("site/out")
        let legacyOut = sourceDir.appendingPathComponent("wiki-site")
        if FileManager.default.fileExists(atPath: sourceDir.appendingPathComponent("site/build.js").path) {
            self.outputDir = siteOut
        } else {
            self.outputDir = legacyOut
        }
        self.jsContext = JSContext()!

        setupBridge()
        loadScripts()
    }

    /// Compile all markdown files in the source directory, then generate the map.
    func compileAll() {
        jsContext.evaluateScript("compile('\(sourceDir.path)', '\(outputDir.path)')")
        jsContext.evaluateScript("compileMap('\(sourceDir.path)', '\(outputDir.path)')")
    }

    /// Lightweight scan: extract metadata from every .md file via regex
    /// (no md.render()). Builds backlink map, search index, previews,
    /// graph — everything except per-page HTML.
    func scanPages() {
        jsContext.evaluateScript("scanPages('\(sourceDir.path)', '\(outputDir.path)')")
    }

    /// Full-render a single page on demand (md.render + HTML assembly).
    @discardableResult
    func compileSingle(slug: String) -> Bool {
        let escaped = slug.replacingOccurrences(of: "'", with: "\\'")
        let result = jsContext.evaluateScript("compilePage('\(escaped)')")
        return result?.toBool() ?? false
    }

    /// Compile a batch of pending pages. Returns the number still remaining.
    func compileNextBatch(size: Int = 5) -> Int {
        let result = jsContext.evaluateScript("compileNextBatch(\(size))")
        return Int(result?.toInt32() ?? 0)
    }

    /// Ad-hoc compile any markdown file (even outside wiki/) into HTML.
    @discardableResult
    func compileAdhoc(filePath: String, outputPath: String) -> Bool {
        let escapedIn = filePath.replacingOccurrences(of: "'", with: "\\'")
        let escapedOut = outputPath.replacingOccurrences(of: "'", with: "\\'")
        let result = jsContext.evaluateScript("compileAdhoc('\(escapedIn)', '\(escapedOut)')")
        return result?.toBool() ?? false
    }

    /// Invalidate a single page's cached HTML.
    func invalidateSingle(slug: String) {
        let escaped = slug.replacingOccurrences(of: "'", with: "\\'")
        jsContext.evaluateScript("invalidatePage('\(escaped)')")
        // Delete the HTML file so compilePage re-renders
        let htmlFile = outputDir.appendingPathComponent("\(slug).html")
        try? FileManager.default.removeItem(at: htmlFile)
    }

    /// Re-read CSS from disk into the JS context.
    func reloadCSS() {
        jsContext.evaluateScript("reloadCSS('\(sourceDir.path)')")
    }

    /// Mark all pages as un-rendered so they recompile with fresh state.
    /// Returns the number of pages queued for recompilation.
    @discardableResult
    func invalidateAll() -> Int {
        let result = jsContext.evaluateScript("invalidateAll()")
        return Int(result?.toInt32() ?? 0)
    }

    /// Full re-scan: re-read all files, rebuild metadata, backlinks, etc.
    func rescan() {
        jsContext.evaluateScript("rescan('\(sourceDir.path)', '\(outputDir.path)')")
    }

    // MARK: - Setup

    private func setupBridge() {
        let fm = FileManager.default

        // readFile(path) → String
        let readFile: @convention(block) (String) -> String = { path in
            (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        }
        jsContext.setObject(readFile, forKeyedSubscript: "readFile" as NSString)

        // writeFile(path, content)
        let writeFile: @convention(block) (String, String) -> Void = { path, content in
            try? content.write(toFile: path, atomically: true, encoding: .utf8)
        }
        jsContext.setObject(writeFile, forKeyedSubscript: "writeFile" as NSString)

        // listDir(path) → [String]
        let listDir: @convention(block) (String) -> [String] = { path in
            (try? fm.contentsOfDirectory(atPath: path).filter { !$0.hasPrefix(".") }) ?? []
        }
        jsContext.setObject(listDir, forKeyedSubscript: "listDir" as NSString)

        // mkdirp(path)
        let mkdirp: @convention(block) (String) -> Void = { path in
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        jsContext.setObject(mkdirp, forKeyedSubscript: "mkdirp" as NSString)

        // fileExists(path) → Bool
        let fileExists: @convention(block) (String) -> Bool = { path in
            fm.fileExists(atPath: path)
        }
        jsContext.setObject(fileExists, forKeyedSubscript: "fileExists" as NSString)

        // fileMtime(path) → Double (seconds since epoch, 0 if not found)
        let fileMtime: @convention(block) (String) -> Double = { path in
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let date = attrs[.modificationDate] as? Date else { return 0 }
            return date.timeIntervalSince1970
        }
        jsContext.setObject(fileMtime, forKeyedSubscript: "fileMtime" as NSString)

        // log(msg)
        let log: @convention(block) (String) -> Void = { msg in
            print("[compiler] \(msg)")
        }
        jsContext.setObject(log, forKeyedSubscript: "log" as NSString)

        // Exception handler
        jsContext.exceptionHandler = { _, exception in
            print("[compiler error] \(exception?.toString() ?? "unknown")")
        }
    }

    private func loadScripts() {
        // Load markdown-it — prefer user's site/ copy, fall back to bundle
        let mdItPath = sourceDir.appendingPathComponent("site/markdown-it.min.js").path
        if let src = try? String(contentsOfFile: mdItPath, encoding: .utf8) {
            jsContext.evaluateScript(src)
        } else if let url = wikiwiseBundle.url(forResource: "markdown-it.min", withExtension: "js"),
                  let src = try? String(contentsOf: url, encoding: .utf8) {
            jsContext.evaluateScript(src)
        }

        // Load CSS as a JS string constant — prefer user's site/style.css
        let cssPath = sourceDir.appendingPathComponent("site/style.css").path
        let cssSource: String? = (try? String(contentsOfFile: cssPath, encoding: .utf8))
            ?? (wikiwiseBundle.url(forResource: "style", withExtension: "css").flatMap { try? String(contentsOf: $0, encoding: .utf8) })
        if let css = cssSource {
            let escaped = css
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            jsContext.evaluateScript("var bundledCSS = `\(escaped)`;")
        }

        // Load client-side JS files as string constants — prefer user's site/ copies
        for (name, varName) in [("app", "bundledAppJS"), ("graph", "bundledGraphJS")] {
            let userPath = sourceDir.appendingPathComponent("site/\(name).js").path
            let jsSource: String? = (try? String(contentsOfFile: userPath, encoding: .utf8))
                ?? (wikiwiseBundle.url(forResource: name, withExtension: "js").flatMap { try? String(contentsOf: $0, encoding: .utf8) })
            if let js = jsSource {
                let escaped = js
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "`", with: "\\`")
                    .replacingOccurrences(of: "$", with: "\\$")
                jsContext.evaluateScript("var \(varName) = `\(escaped)`;")
            }
        }

        // Load map.html as a string constant — prefer user's site/ copy
        let mapPath = sourceDir.appendingPathComponent("site/map.html").path
        let mapSource: String? = (try? String(contentsOfFile: mapPath, encoding: .utf8))
            ?? (wikiwiseBundle.url(forResource: "map", withExtension: "html").flatMap { try? String(contentsOf: $0, encoding: .utf8) })
        if let html = mapSource {
            let escaped = html
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            jsContext.evaluateScript("var bundledMapHTML = `\(escaped)`;")
        }

        // Load map-3d.html as a string constant — prefer user's site/ copy
        let map3dPath = sourceDir.appendingPathComponent("site/map-3d.html").path
        let map3dSource: String? = (try? String(contentsOfFile: map3dPath, encoding: .utf8))
            ?? (wikiwiseBundle.url(forResource: "map-3d", withExtension: "html").flatMap { try? String(contentsOf: $0, encoding: .utf8) })
        if let html = map3dSource {
            let escaped = html
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            jsContext.evaluateScript("var bundledMap3dHTML = `\(escaped)`;")
        }

        // Load build.js — prefer user's site/build.js
        let buildPath = sourceDir.appendingPathComponent("site/build.js").path
        if let src = try? String(contentsOfFile: buildPath, encoding: .utf8) {
            jsContext.evaluateScript(src)
        } else if let url = wikiwiseBundle.url(forResource: "build", withExtension: "js"),
                  let src = try? String(contentsOf: url, encoding: .utf8) {
            jsContext.evaluateScript(src)
        }
    }
}
