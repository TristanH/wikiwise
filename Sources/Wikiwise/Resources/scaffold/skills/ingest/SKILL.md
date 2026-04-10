---
name: ingest
description: Ingest a source into the wiki — read it, create a source-summary page, propagate claims into concept/entity pages, update index and log.
---

# Ingest a source

Read the source material provided by the user (URL, file path, or pasted text). Then:

1. **Save the raw source** into `raw/` as an immutable document.
2. **Create a source-summary page** at `wiki/sources/<slug>.md` with frontmatter (`type`, `date`, `author`, `url`, `raw`).
3. **Propagate claims** — update or create concept/entity pages at the `wiki/` root that are affected by this source. Cite the source inline with `([[slug]])`.
4. **Update `wiki/index.md`** — add the new page(s) to the catalog with one-line summaries.
5. **Append to `wiki/log.md`** — add a timestamped entry: `## [YYYY-MM-DD HH:MM] ingest | <title>`.

After ingesting, report what pages were created or updated.
