# Wikiwise

A native macOS wiki reader — SwiftUI app with sidebar file browser and rendered markdown content.

## Development

- Build: `swift build`
- Run: `.build/arm64-apple-macosx/debug/Wikiwise`
- Release: `bash scripts/build-release.sh <version>` — **always use this for releases.** It builds a universal binary (arm64 + x86_64), code-signs with the Readwise Developer ID, creates a DMG with drag-to-Applications, notarizes with Apple, and staples the ticket. Never build releases manually or skip this script.

## Architecture

- SwiftUI macOS app, built via SwiftPM (no Xcode project)
- `NavigationSplitView`: sidebar file tree + detail content pane
- File tree built from scanning a user-selected folder for `.md` files
- Markdown rendering via WKWebView with JavaScriptCore compiler

## Wiki scaffold

When users create a new wiki, the app copies the template from `Sources/Wikiwise/Resources/scaffold/`. This is the source of truth for the default wiki structure, including:

- `CLAUDE.md` — the wiki schema (conventions, writing style, workflows)
- `AGENTS.md` — cross-agent instructions for Cursor, Codex, etc.
- `llm-wiki.md` — Karpathy's original pattern description
- `skills/` — Claude Code skills (ingest, lint, import-readwise, digest, etc.)
- `wiki/` — seed pages (home.md, index.md, log.md)
