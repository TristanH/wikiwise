import Foundation

/// Creates a new wiki folder with the standard structure:
///   raw/
///   wiki/  (home.md, index.md, log.md)
///   site/  (build.js, style.css, out/)
///   .claude/skills/  (ingest.md, lint.md, import-readwise.md)
///   CLAUDE.md
enum WikiScaffold {

    enum ScaffoldError: Error {
        case missingResources
    }

    /// Create a new wiki at the given URL.
    /// - Parameters:
    ///   - url: The directory to create the wiki in (will be created if needed).
    ///   - name: Human-readable wiki name, used in CLAUDE.md.
    static func create(at url: URL, name: String) throws {
        let fm = FileManager.default

        // Create directory structure
        let dirs = [
            url.path,
            url.appendingPathComponent("raw").path,
            url.appendingPathComponent("wiki").path,
            url.appendingPathComponent("wiki/sources").path,
            url.appendingPathComponent("site").path,
            url.appendingPathComponent("site/out").path,
            url.appendingPathComponent(".claude").path,
            url.appendingPathComponent(".claude/skills").path,
        ]
        for dir in dirs {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        // Copy scaffold templates from the app bundle
        guard let scaffoldDir = Bundle.module.url(forResource: "scaffold", withExtension: nil) else {
            throw ScaffoldError.missingResources
        }

        // CLAUDE.md — replace placeholder with wiki name
        let claudeTemplate = try String(contentsOf: scaffoldDir.appendingPathComponent("CLAUDE.md"), encoding: .utf8)
        let claudeContent = claudeTemplate.replacingOccurrences(of: "{{WIKI_NAME}}", with: name)
        try claudeContent.write(to: url.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)

        // AGENTS.md — cross-agent instructions (Cursor, Codex, Windsurf, etc.)
        let agentsSource = scaffoldDir.appendingPathComponent("AGENTS.md")
        try fm.copyItem(at: agentsSource, to: url.appendingPathComponent("AGENTS.md"))

        // llm-wiki.md — Karpathy's pattern description (read-only reference)
        let llmWikiSource = scaffoldDir.appendingPathComponent("llm-wiki.md")
        if fm.fileExists(atPath: llmWikiSource.path) {
            try fm.copyItem(at: llmWikiSource, to: url.appendingPathComponent("llm-wiki.md"))
        }

        // Wiki seed files
        let wikiFiles = ["home.md", "index.md", "log.md"]
        for file in wikiFiles {
            let source = scaffoldDir.appendingPathComponent("wiki/\(file)")
            let dest = url.appendingPathComponent("wiki/\(file)")
            // home.md has a {{WIKI_PATH}} placeholder for the terminal snippet
            if file == "home.md" {
                let template = try String(contentsOf: source, encoding: .utf8)
                let content = template.replacingOccurrences(of: "{{WIKI_PATH}}", with: url.path)
                try content.write(to: dest, atomically: true, encoding: .utf8)
            } else {
                try fm.copyItem(at: source, to: dest)
            }
        }

        // Claude Code skills (each is a directory with SKILL.md)
        let skillDirs = ["ingest", "lint", "import-readwise", "fetch-readwise-document", "fetch-readwise-highlights"]
        for skill in skillDirs {
            let source = scaffoldDir.appendingPathComponent("skills/\(skill)")
            let dest = url.appendingPathComponent(".claude/skills/\(skill)")
            try fm.copyItem(at: source, to: dest)
        }

        // Claude Code settings.json to register skills
        let settings = """
        {
          "permissions": {
            "allow": ["Read", "Write", "Edit", "Glob", "Grep", "Bash(*)"]
          },
          "hooks": {
            "UserPromptSubmit": [
              {
                "matcher": "",
                "hooks": [
                  {
                    "type": "command",
                    "command": "echo \\"[Active file: $(cat .claude/active-file 2>/dev/null || echo none)]\\"",
                    "timeout": 2000
                  }
                ]
              }
            ]
          }
        }
        """
        try settings.write(to: url.appendingPathComponent(".claude/settings.json"), atomically: true, encoding: .utf8)

        // Copy build.js and style.css into site/
        if let buildJS = Bundle.module.url(forResource: "build", withExtension: "js"),
           let styleCSS = Bundle.module.url(forResource: "style", withExtension: "css") {
            try fm.copyItem(at: buildJS, to: url.appendingPathComponent("site/build.js"))
            try fm.copyItem(at: styleCSS, to: url.appendingPathComponent("site/style.css"))
        }

        // Copy supporting JS files (markdown-it, app.js, graph.js, map.html)
        let supportFiles: [(resource: String, ext: String, dest: String)] = [
            ("markdown-it.min", "js", "site/markdown-it.min.js"),
            ("app", "js", "site/app.js"),
            ("graph", "js", "site/graph.js"),
            ("map", "html", "site/map.html"),
        ]
        for file in supportFiles {
            if let source = Bundle.module.url(forResource: file.resource, withExtension: file.ext) {
                try fm.copyItem(at: source, to: url.appendingPathComponent(file.dest))
            }
        }

        // .gitignore for compiled output
        let gitignore = "site/out/\npublish.json\n"
        try gitignore.write(to: url.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
    }
}
