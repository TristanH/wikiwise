---
name: digest
description: Deep-propagate one or more ingested sources across the wiki — update concept/entity/question pages, flag contradictions, create new pages where warranted. Optional step after ingest to ensure claims ripple through the full wiki.
---

# Digest source

Goal: take one or more raw files that already have a wiki summary page (created by ingest) and produce the full ripple effect — surgical propagation into existing pages + new pages where genuinely warranted + index/log updates. This is the skill that turns an ingested source into *integrated* knowledge across the wiki.

## When to use

- After running the `ingest` skill, as an optional deeper pass.
- When the user says "digest" / "propagate" a source across the wiki.
- When you notice source-summary pages whose claims haven't been woven into concept or entity pages yet.

## Preconditions

- At least one source-summary page in `wiki/` whose claims haven't been fully propagated.
- You have read the wiki schema (`CLAUDE.md` or `AGENTS.md`) and `wiki/home.md` at least once in this session.

## Architecture

If your agent supports subagents (e.g., Claude Code's `Agent` tool), delegate the heavy lifting:
1. Identify which sources need digesting.
2. Read the wiki schema, `wiki/home.md`, and `wiki/index.md` to understand the current wiki state.
3. Dispatch a subagent with a tight brief (see template below).
4. Receive the subagent's report and relay it concisely to the user.

**Why delegate:** the main thread should not hold multiple source bodies simultaneously. The subagent reads sources once, makes surgical edits, and returns a diff summary.

If your agent does **not** support subagents (e.g., Codex, Cursor), do the work inline — read the schema, identify sources, and make the edits yourself following the same rules in the subagent brief below.

## Step 1 — Identify sources to digest

If the user didn't name specific files, check which source-summary pages exist but whose claims don't appear in concept/entity pages:

```bash
# Find source-summary pages (have type: frontmatter)
grep -l "^type:" wiki/*.md
```

Confirm with the user before digesting if there's ambiguity.

## Step 2 — Load the wiki's current state

Read these three files (and pass their content to the subagent, if using one):

- `CLAUDE.md` (or `AGENTS.md`) — schema, conventions.
- `wiki/home.md` — current through-line and live tensions.
- `wiki/index.md` — full catalog of existing pages.

## Step 3 — Dispatch the digest subagent (or do it inline)

If using subagents, launch one with this brief (adapt per run). Otherwise, follow these same instructions yourself:

> **Job:** Digest source(s) into the wiki. Follow the wiki schema (`CLAUDE.md` / `AGENTS.md`) exactly.
>
> **Sources to digest:** `<list of wiki source-summary pages>`
>
> **Current wiki state:** `wiki/home.md` is the human narrative; `wiki/index.md` is the agent catalog. Read `home.md` first to ground yourself, then `index.md` to know what pages exist.
>
> **For each source, do the full ripple:**
>
> 1. **Read the source summary and its raw.** Once, carefully.
>
> 2. **Propagate and cross-link.** Make surgical edits (not rewrites) to existing pages the source materially informs. Rules:
>    - Add to existing paragraphs/sections where the new material belongs; don't create duplicate sections.
>    - Cite the source: `([[<slug>]])`.
>    - If the source contradicts an existing claim, add a `> [!contradiction]` callout inline.
>    - If a claim has a canonical home elsewhere, link rather than duplicate.
>    - **Add backlinks:** when you update an existing page to reference a new concept, also edit the new concept page to link back. Every connection should be bidirectional.
>    - **No orphans:** after propagation, every source-summary and every concept page must have at least 2 inbound `[[wikilinks]]` from other pages. If a page has zero inbound links, find related pages and add references to them.
>
> 3. **Create new pages** *only* when the material genuinely warrants one — a new entity, concept, open question, or strategic position — not for every tangent. Lean conservative.
>
> 4. **Update `wiki/index.md`** to list every new page under the right category.
>
> 5. **Prepend one log entry per source digested** to `wiki/log.md` (below the header): `## [YYYY-MM-DD HH:MM] digest | <title>`. Newest entries at top.
>
> **Rules:**
>
> - **Never modify `raw/`.** Read-only.
> - **Stay flat.** No new subdirectories inside `wiki/` — `wiki/sources/` is the only allowed subdirectory.
> - **Don't invent facts.** If the source doesn't say something, don't claim it.
> - **Don't touch schema files (`CLAUDE.md`, `AGENTS.md`) or `home.md`** unless the source forces a schema change (rare — flag it, don't just do it).
> - **Don't rewrite existing pages wholesale.** Surgical edits only.
> - **Don't duplicate content across pages.** One canonical home per claim, others link.
>
> **Deliverable (under 300 words):**
>
> 1. New pages created (filenames only).
> 2. Existing pages updated (filenames only).
> 3. Any contradictions flagged.
> 4. Judgment calls worth the user reviewing.
> 5. Any new open questions the wiki should track.

## Step 4 — Relay the subagent's report

Summarize the subagent's return concisely (under 200 words). Highlight:
- Anything flagged as a judgment call.
- Any contradictions.
- Any new open questions surfaced.

Then ask the user if anything needs adjustment.

## Batching multiple sources

If multiple sources need digesting and you're using subagents, dispatch **one** subagent for all of them rather than one per source. Cross-references between sources stay coherent that way.

## Rules

- **Never** skip Step 2. You (or the subagent) need that context.
- **Never** run this on a source without an existing summary page — run `ingest` first.
- If using subagents: **never** pre-read raws in the main thread before dispatching. The subagent reads them. Prefer one subagent for all sources over N subagents for N sources.
