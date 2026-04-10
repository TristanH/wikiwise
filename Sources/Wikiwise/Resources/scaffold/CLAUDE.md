# {{WIKI_NAME}} — schema

A personal wiki maintained by an LLM agent, following the [llm-wiki pattern](llm-wiki.md) by Andrej Karpathy. Read `llm-wiki.md` for the full pattern description — this schema is our implementation of it.

## Layout

- `llm-wiki.md` — Karpathy's pattern description (reference, read-only).
- `raw/` — immutable source documents. Read-only for the LLM.
- `wiki/` — LLM-maintained markdown. All edits here. Categories live in `index.md`, not in the filesystem.
  - `home.md` — human entry point. Narrative overview, current state of thinking. **Always include visuals** — inline SVG concept maps showing how ideas connect, diagrams of key frameworks, or relationship graphs. The home page should feel rich and visual, not just a wall of text.
  - `index.md` — agent catalog. Flat list of every page with a one-line summary, grouped by category.
  - `log.md` — append-only chronological log.
  - `sources/` — source-summary pages (one per ingested source).
- `site/` — build tooling and compiled output.
  - `site/out/` — compiled HTML (auto-generated, do not edit).
  - `site/build.js` — the wiki compiler (markdown to HTML).
  - `site/style.css` — the wiki theme.

## Conventions

- Link with Obsidian-style `[[wikilinks]]`. Bare filename, no path.
- Every claim should cite a source: `([[source-slug]])`.
- Source-summary pages start with a frontmatter block: `type`, `date`, `author`, `url`, `raw` (path into `raw/`).
- Log entries prefix: `## [YYYY-MM-DD HH:MM] <op> | <title>` (local time).

## Writing style

Wiki pages are short blog posts, not reference dumps. Write for a human reader who reads top-to-bottom.

1. **TL;DR first** — one or two sentences that give away the answer.
2. **What it means** — 2-4 short narrative paragraphs.
3. **The argument** — reasoning, evidence, counter-arguments, organized by idea.
4. **Extras** (optional) — loose threads, adjacent ideas.

Voice: opinionated, direct, declarative. Length: most pages under 800 words.

## Live viewer

The user is reading this wiki in the Wikiwise app, which watches the project directory for changes. When you edit `.md` or `.css` files, the app detects the change via FSEvents and automatically recompiles and refreshes the page the user is viewing.

**If auto-refresh doesn't pick up your changes**, touch the `.rebuild` trigger file at the project root:

```sh
touch .rebuild
```

This forces a full recompile of every page and refreshes the current view. The app deletes the file after processing, so it's safe to touch repeatedly. Use this after bulk operations (many files changed at once) or if you suspect the watcher missed something.

**What the user sees:** `.claude/active-file` contains the relative path of the page currently open in the app. Read it to know what the user is looking at.

## Workflows

**Ingest a new source.** Read it. Create/update the source-summary page at `wiki/sources/<slug>.md`. Propagate claims into relevant concept and entity pages. Update `index.md`. Append to `log.md`.

**Keep `home.md` alive.** Update `home.md` as soon as the first few sources are ingested — don't wait until the wiki is "done." Every time new sources change the picture, revise `home.md` to reflect the current state of thinking. The home page is the wiki's front door; a stale home page makes the whole wiki feel abandoned.

**Query.** Read `index.md` first. Drill into pages. If the answer is non-trivial, file it back as a new page.

**Lint.** Scan for contradictions, orphans, stale claims, missing cross-links.
