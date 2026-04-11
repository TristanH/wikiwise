---
name: lint
description: Health-check the wiki for contradictions, orphan pages, stale claims, and missing cross-links.
---

# Lint the wiki

Scan every page in `wiki/` and check for:

1. **Orphan pages (highest priority)** — pages not linked from any other page. For each orphan, find 2-3 related pages and add `[[wikilinks]]` to them. Don't just report orphans — fix them.
2. **Dead-end pages** — pages with no outbound `[[wikilinks]]`. Add links to related concepts/sources.
3. **Missing cross-links** — pages that discuss the same topic but don't link to each other. Add the links.
4. **Contradictions** — claims on one page that conflict with claims on another. Mark with `> [!contradiction]` callouts.
5. **Broken wikilinks** — `[[links]]` pointing to pages that don't exist. Fix or remove them.
6. **Stale claims** — claims citing sources that have been superseded or are very old.
7. **Stale `home.md`** — if home.md doesn't reflect the current state of the wiki (missing major themes, outdated narrative), update it.

**Fix, don't just report.** For items 1-3 and 5, make the edits yourself. For items 4 and 6-7, report findings and suggest fixes.

Report what was fixed and what needs human review. Suggest new questions or sources worth seeking out.

Append to `wiki/log.md`: `## [YYYY-MM-DD HH:MM] lint | <summary>`.
