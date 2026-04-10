---
name: fetch-readwise-highlights
description: Mine Readwise highlights via vector search, group by parent document, and write highlight collections into raw/. Streams results to disk without loading into context, then chains into ingest.
allowed-tools: Bash(*) Read Write Edit Glob Grep
---

# Fetch Readwise Highlights

Goal: pull **relevance-filtered highlights** from the user's Readwise library (books, articles, tweets, podcasts) into `raw/` as per-parent-document markdown files, then hand them to `ingest`. The unit is a parent doc; the content is only the highlights that matched one or more search queries.

Highlights are valuable because they're already user-curated and compact — a book with 80 highlights is ~3-6k tokens vs. the full book being unusable.

## Preconditions

- `readwise` CLI installed and authenticated.
- `jq` installed.
- `raw/` directory exists.
- The wiki has a `wiki/home.md` with a clear through-line, or the user has told you the research frame.

## Core pattern

### Step 1 — Formulate vector search queries

Read `wiki/home.md` and scan `wiki/index.md` for open questions. Formulate 5-10 candidate queries covering:

- Core topic terms
- Adjacent debate vocabulary
- Named entities that matter
- Phenomena and mechanisms
- Contrarian framings

**Show the query list to the user** before searching. Let them add, remove, or adjust. Don't silently batch queries.

### Step 2 — Run vector searches

For each query, redirect output to a temp file — do **not** pipe to stdout:

```bash
readwise readwise-search-highlights \
  --vector-search-term "<query>" \
  --limit 30 --json \
  > /tmp/rwhl_query_<N>.json
```

Batch all queries in one bash call.

### Step 3 — Merge, dedupe, group by parent document

```bash
jq -s '
  [ .[] | .[] ]
  | unique_by(.id)
  | group_by(.attributes.document_title + "|" + .attributes.document_author)
  | map({
      title: .[0].attributes.document_title,
      author: .[0].attributes.document_author,
      category: .[0].attributes.document_category,
      doc_tags: .[0].attributes.document_tags,
      match_count: length,
      top_score: (map(.score) | max),
      highlights: [ .[] | {
        id, score,
        text: .attributes.highlight_plaintext,
        note: .attributes.highlight_note,
        tags: .attributes.highlight_tags
      }]
    })
  | sort_by(-.match_count, -.top_score)
' /tmp/rwhl_query_*.json > /tmp/rwhl_grouped.json
```

**Report to the user:** number of unique parent docs, top 10 by match count. Ask them to confirm the inclusion threshold (default: `match_count >= 2`, or `match_count == 1 && top_score > 0.5`). Let them prune off-topic results before writing files.

### Step 4 — Write per-doc raw files

For each parent doc passing the threshold, write `raw/<slug>_highlights.md`. The `_highlights` suffix distinguishes these from full-document raws.

```bash
jq -c '.[] | select(.match_count >= 2 or (.match_count == 1 and .top_score > 0.5))' /tmp/rwhl_grouped.json \
| while IFS= read -r doc; do
    slug=$(echo "$doc" | jq -r '(.author // "unknown" | ascii_downcase | gsub("[^a-z0-9]+"; "-") | .[0:20]) + "_" + (.title | ascii_downcase | gsub("[^a-z0-9]+"; "-") | .[0:35]) + "_highlights"')
    {
      echo "$doc" | jq -r '"# Highlights: " + .title + "\n\n**Author:** " + .author + "\n**Category:** " + .category + "\n**Document tags:** " + (.doc_tags | if length == 0 then "none" else join(", ") end) + "\n**Match count:** " + (.match_count|tostring) + "\n**Top score:** " + (.top_score|tostring) + "\n\n> Note: these are the matched highlights only, not every highlight in the doc. Re-run with more queries for broader coverage.\n\n---\n"'
      echo "$doc" | jq -r '.highlights[] | "> " + (.text | gsub("\n"; "\n> ")) + "\n" + (if .note != "" and .note != null then "**Note:** " + .note + "\n" else "" end) + (if (.tags // [] | length) > 0 then "*Tags: " + (.tags | join(", ")) + "*\n" else "" end) + "\n---\n"'
    } > "raw/$slug.md"
  done
```

### Step 5 — Verify without reading the bodies

```bash
ls -la raw/*_highlights.md
wc -l raw/*_highlights.md
```

Do **not** `cat` or `Read` a highlights file unless the user asks.

### Step 6 — Report, then chain into ingest

Report: number of parent docs landed, filenames, match counts, and any docs you dropped. Then invoke the `ingest` skill on all new `*_highlights.md` raws. Tell the ingest step these are **highlight collections** — cite individual highlights rather than re-paraphrasing.

## JSON shapes (don't re-probe these)

- `readwise-search-highlights --json` → **top-level array**. Each item: `id`, `score`, `attributes.{document_title, document_author, document_category, highlight_plaintext, highlight_note, highlight_tags}`.

## Rules

- **Never** run `readwise-search-highlights` with stdout going to tool output — always redirect to `/tmp/`.
- **Never** write JSON files to `raw/` — all raw files must be markdown (`.md`). Temp JSON goes in `/tmp/`.
- **Never** `Read` or `cat` a `raw/` file you just wrote unless the user explicitly asks.
- **Always confirm** the query set with the user before searching.
- **Always chain into `ingest`** unless the user said "just fetch."
- A 30-doc haul is probably too many; 5-15 is a normal batch.
