# {{WIKI_NAME}} — schema

A personal wiki maintained by an LLM agent, following the [llm-wiki pattern](llm-wiki.md) by Andrej Karpathy. Read `llm-wiki.md` for the full pattern description — this schema is our implementation of it.

## Layout

- `llm-wiki.md` — Karpathy's pattern description (reference, read-only).
- `raw/` — immutable source documents. Read-only for the LLM.
- `wiki/` — LLM-maintained markdown. All edits here. Categories live in `index.md`, not in the filesystem.
  - `home.md` — human entry point. Narrative overview, current state of thinking. Use inline SVG concept maps to visualize how ideas connect. Include images where they help tell the story.
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

## Workflows

**Ingest a new source.** Read it. Create/update the source-summary page at `wiki/sources/<slug>.md`. Propagate claims into relevant concept and entity pages. Update `index.md`. Append to `log.md`.

**Keep `home.md` alive.** Update `home.md` as soon as the first few sources are ingested — don't wait until the wiki is "done." Every time new sources change the picture, revise `home.md` to reflect the current state of thinking. The home page is the wiki's front door; a stale home page makes the whole wiki feel abandoned.

**Query.** Read `index.md` first. Drill into pages. If the answer is non-trivial, file it back as a new page.

**Lint.** Scan for contradictions, orphans, stale claims, missing cross-links.
