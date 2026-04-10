# Agent Instructions

This is a wiki maintained by an LLM agent. Read `CLAUDE.md` for the full schema, conventions, and workflows.

## Quick reference

- **`raw/`** — immutable source documents. Read-only.
- **`wiki/`** — LLM-maintained markdown pages. All edits here. Source summaries go in `wiki/sources/`.
- **`site/`** — build tooling and compiled output. `site/out/` is auto-generated.
- **`CLAUDE.md`** — the wiki schema. Your source of truth for how this wiki works.

## Key conventions

- Link with `[[wikilinks]]`. Bare filename, no path.
- Cite sources inline: `([[source-slug]])`.
- Wiki pages are short blog posts, not reference dumps. TL;DR first, then the argument.
- After any ingest, update `wiki/index.md` and append to `wiki/log.md`.

## Skills

Agent skills are in `.claude/skills/`. If your agent supports skill files, these should be available automatically. Otherwise, read them for workflow instructions:

- `ingest/` — add a source to the wiki
- `lint/` — health-check for contradictions and orphans
- `import-readwise/` — search and import from Readwise (orchestrator)
- `fetch-readwise-document/` — stream a Reader document into raw/ without loading the body into context
- `fetch-readwise-highlights/` — vector-search highlights, group by parent doc, write to raw/

## Running your agent

WikiWise includes a built-in terminal in the right sidebar — click the terminal icon in the toolbar. You can also run your agent in any external terminal pointed at this folder.
