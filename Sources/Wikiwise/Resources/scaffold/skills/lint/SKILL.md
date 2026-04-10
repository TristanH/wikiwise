---
name: lint
description: Health-check the wiki for contradictions, orphan pages, stale claims, and missing cross-links.
---

# Lint the wiki

Scan every page in `wiki/` and check for:

1. **Contradictions** — claims on one page that conflict with claims on another. Mark with `> [!contradiction]` callouts.
2. **Orphan pages** — pages not linked from any other page or from `index.md`.
3. **Broken wikilinks** — `[[links]]` pointing to pages that don't exist.
4. **Stale claims** — claims citing sources that have been superseded or are very old.
5. **Missing cross-links** — pages that discuss the same topic but don't link to each other.

Report findings grouped by category. Suggest new questions or sources worth seeking out.

Append to `wiki/log.md`: `## [YYYY-MM-DD HH:MM] lint | <summary>`.
