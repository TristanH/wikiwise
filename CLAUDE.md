# Wikiwise

A native macOS wiki reader — SwiftUI app with sidebar file browser and rendered markdown content.

## Development

- Build: `swift build`
- Run: `.build/arm64-apple-macosx/debug/Wikiwise`
- Screenshots: use `screencapture -x -D 2` (user's primary display is display 2, the external monitor)
- **Visual verification required:** After any change that affects display or could break the app, build it, open it on display 2, screenshot it, and click around to confirm the change works visually. Don't trust code alone — verify on screen.

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
