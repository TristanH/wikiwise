---
name: ingest
description: Ingest a source into the wiki — read it, create a source-summary page, propagate claims into concept/entity pages, update index and log.
---

# Ingest a source

Read the source material provided by the user (URL, file path, or pasted text). Then:

1. **Save the raw source** into `raw/` as an immutable document.
2. **Create a source-summary page** at `wiki/sources/<slug>.md` with frontmatter (`type`, `date`, `author`, `url`, `raw`). If the raw source contains images, include the best ones in the summary page — they make source pages far more useful to browse.
3. **Propagate claims** — update or create concept/entity pages at the `wiki/` root that are affected by this source. Cite the source inline with `([[slug]])`.
4. **Cross-link aggressively** — this is the step most often skipped and the most important:
   - Read `wiki/index.md` to find every page related to the new material.
   - **Add `[[wikilinks]]` FROM existing pages TO the new pages.** Open 2-3 related existing pages and edit them to reference the new content where it's relevant.
   - **Add `[[wikilinks]]` FROM new pages TO existing pages.** Every new page should link out to related concepts, entities, and sources already in the wiki.
   - The goal: no orphans. Every new page should have inbound links from existing pages AND outbound links to them.
5. **Update `wiki/index.md`** — add the new page(s) to the catalog with one-line summaries.
6. **Update `wiki/home.md`** — if the new source materially changes the narrative or adds a new theme, revise home.md. Don't wait for the wiki to be "complete."
7. **Append to `wiki/log.md`** — add a timestamped entry: `## [YYYY-MM-DD HH:MM] ingest | <title>`.

After ingesting, report what pages were created or updated, and list the cross-links added (which existing pages now link to the new content).
