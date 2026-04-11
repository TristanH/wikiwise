---
name: fetch-readwise-document
description: Fetch one or more Readwise Reader documents into raw/ without loading bodies into context. Streams content to disk via jq pipe, then chains into ingest.
allowed-tools: Bash(*) Read Write Edit Glob Grep
---

# Fetch Readwise Document

Goal: grab a Reader document (or several) and drop it into `raw/` **without ever loading the full body into context**. Only small metadata (title, author, url, date, category, doc_id) is allowed in context. The body gets streamed from CLI to file via a pipe.

## Preconditions

- `readwise` CLI installed and authenticated.
- `jq` installed (`brew install jq` if missing).
- A `raw/` directory exists.

## Core pattern (single doc)

Given a Readwise URL (`https://read.readwise.io/read/<id>`), a bare doc_id, or a search query:

### Step 1 — Resolve doc_id

If the user gave a URL: the id is the last path segment. No CLI call needed.

If the user gave a **specific title**, use `--title-search` (note: `--query` is also required even when filtering by title):

```bash
readwise reader-search-documents --query "<title words>" --title-search "<title words>" --limit 5 --json \
  | jq -r '.[] | "\(.document_id)\t\(.title)\t\(.author)\t\(.category)"'
```

For a topical search (no exact title), use `--query` alone. Add `--author-search` when you know the author. Show candidates to the user if ambiguous.

### Step 2 — Fetch metadata (mandatory)

`reader-get-document-details` does **not** return `image_url`, `source_url`, `published_date`, `word_count`, or `site_name`. Pull those from `reader-list-documents`:

```bash
readwise reader-list-documents --id <DOC_ID> \
  --response-fields title,author,url,source_url,category,published_date,saved_at,site_name,word_count,image_url \
  --json | jq '.results[0]'
```

- `image_url` — cover/header image. Embed as `![](url)` in the raw header.
- `source_url` — the original URL (not the `read.readwise.io` shell). Use as the canonical `**Source:**`.

If `image_url` is null, skip the markdown image embed. Don't fail the fetch.

Pick a filename slug: `<author-last-or-source>_<short-title-slug>.md`, lowercase, hyphen-separated, no punctuation, max 60 chars.

### Step 3 — Stream the body to disk

**This is the critical command.** Never run `reader-get-document-details` without piping into jq and redirecting to a file.

```bash
{
  printf '# %s\n\n![](%s)\n\n**Source:** %s\n**Readwise URL:** https://read.readwise.io/read/%s\n**Readwise ID:** %s\n**Date:** %s\n**Author:** %s\n**Category:** %s\n**Cover image:** %s\n\n---\n\n' \
    "<TITLE>" "<IMAGE_URL>" "<SOURCE_URL>" "<DOC_ID>" "<DOC_ID>" "<DATE>" "<AUTHOR>" "<CATEGORY>" "<IMAGE_URL>"
  readwise reader-get-document-details --document-id <DOC_ID> --json \
    | jq -r '.content'
} > raw/<slug>.md
```

Drop the `![](%s)\n\n` line if `image_url` is null.

### Step 4 — Verify without reading the body

```bash
wc -l raw/<slug>.md && head -n 10 raw/<slug>.md
```

`head -n 10` only shows the header you wrote. If line count is 0, something went wrong.

### Step 5 — Report, then chain into ingest

Tell the user: filename, word count (from metadata), and that the body is on disk. Do not summarize the content — you haven't read it. Then invoke the `ingest` skill on the raw file.

## Multi-doc pattern

Resolve all doc_ids first (Step 1), fetch metadata for all (Step 2), then loop:

```bash
for id in <ID1> <ID2> <ID3>; do
  slug=$(...)  # derived per-id from metadata
  {
    printf '...header...'
    readwise reader-get-document-details --document-id "$id" --json | jq -r '.content'
  } > "raw/$slug.md"
done
wc -l raw/*.md
```

Hold off on `ingest` until all fetches are done, then ingest the batch using parallel subagents (see import-readwise skill Step 4).

## JSON shapes (don't re-probe these)

- `reader-search-documents --json` → **top-level array**. Each item: `document_id`, `title`, `author`, `category`, `url`, `matches[]`.
- `reader-list-documents --json` → **`{count, nextPageCursor, results: [...]}`**. Access with `jq -r '.results[0] | ...'`.
- `reader-get-document-details --json` → **flat object** with keys `id, title, author, category, tags, notes, content`. The body is at `.content`. No `image_url`, `source_url`, `published_date`.

## Tweet caveat

When a user saves a tweet that is a reply, Reader stores the **parent thread** as the document. The `source_url` (from list-documents) points at the actually-saved tweet. The `image_url` is the parent author's avatar. Surface this to the user when fetching tweet replies.

## CLI flag reference (don't guess these)

The Readwise CLI uses `--document-id`, NOT `--id`. Here are the exact flags:

```bash
# Get document details — use --document-id (NOT --id)
readwise reader-get-document-details --document-id <DOC_ID> --json

# List documents — use --id to filter by doc ID
readwise reader-list-documents --id <DOC_ID> --json

# Search documents
readwise reader-search-documents --query "<text>" --json
readwise reader-search-documents --query "<text>" --title-search "<title>" --json

# Search highlights
readwise readwise-search-highlights --vector-search-term "<text>" --limit 30 --json
```

**Common mistakes to avoid:**
- `reader-get-document-details --id` → WRONG, use `--document-id`
- `reader-list-documents --document-id` → WRONG, use `--id`
- Running `--help` to discover flags → DON'T, use this reference

## Rules

- **Never** run `reader-get-document-details` without `| jq -r '.content' > <file>`. No exceptions.
- **Never** `Read` or `cat` a `raw/` file you just wrote unless the user explicitly asks.
- **Never** probe JSON shapes with `jq 'keys'`.
- **Never** run `--help` to discover CLI flags — use the reference above.
- **Prefer `--title-search`** over `--query` when the user names a specific title.
- If metadata is missing fields, use `null` or `unknown` — do not fetch the body to find them.
- Confirm with the user before overwriting an existing `raw/` file.
