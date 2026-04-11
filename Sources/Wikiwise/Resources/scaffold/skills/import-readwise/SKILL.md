---
name: import-readwise
description: Import highlights and documents from Readwise into the wiki using the Readwise CLI (not MCP). Searches and browses interactively, then delegates to fetch-readwise-document and fetch-readwise-highlights for streaming large content to disk.
allowed-tools: Bash(*) Read Write Edit Glob Grep Agent
---

# Import from Readwise

Pull the user's reading history and highlights from Readwise, then compile them into wiki pages.

**Use the `readwise` CLI tool for all Readwise access.** Do not use MCP tools, Readwise APIs directly, or any other method — the CLI handles authentication, pagination, and rate limiting. All commands run via Bash.

Use the Readwise CLI freely to search, browse, and explore the user's library. When it's time to actually pull large content into `raw/`, delegate to:

- **`fetch-readwise-document`** — streams a full Reader document to disk without loading the body into context.
- **`fetch-readwise-highlights`** — vector-searches highlights, groups by parent doc, and writes highlight collections to disk.

## Step 0: Ensure the Readwise CLI is installed and authenticated

Run these checks in order. Stop and fix each issue before continuing.

1. **Check if the CLI exists:** `which readwise`
2. **If not installed**, check if Node is available: `which node`
   - **If Node exists:** run `npm install -g @readwise/cli`
   - **If Node is missing:** install it directly:
     ```
     curl -fsSL https://nodejs.org/dist/v22.15.0/node-v22.15.0-darwin-arm64.tar.xz | tar -xJ -C /usr/local/lib
     ln -sf /usr/local/lib/node-v22.15.0-darwin-arm64/bin/node /usr/local/bin/node
     ln -sf /usr/local/lib/node-v22.15.0-darwin-arm64/bin/npm /usr/local/bin/npm
     ln -sf /usr/local/lib/node-v22.15.0-darwin-arm64/bin/npx /usr/local/bin/npx
     ```
     Then run `npm install -g @readwise/cli`
3. **Check if authenticated:** `readwise reader-list-documents --limit 1`
4. **If not authenticated:** run `readwise login` (opens the user's browser for OAuth — wait for it to complete).

Do not proceed until the CLI is installed and authenticated.

## Step 1: Ask the user what to import

Suggest importing by topic first — it's the most useful starting point:
- **By topic** — search for documents and highlights related to a subject (recommended)
- Import specific documents (by URL, title, or search)
- Filter by date range or source type (books, articles, podcasts, tweets)
- Mine their highlights for material relevant to the wiki

## Step 2: Search and browse

Use the Readwise CLI to explore the user's library interactively:

```bash
# Search for documents by topic
readwise reader-search-documents --query "<topic>" --limit 20 --json

# List recent documents
readwise reader-list-documents --limit 20 --json

# Search highlights by topic
readwise readwise-search-highlights --vector-search-term "<topic>" --limit 30 --json
```

Show results to the user and let them pick what to import. This is the interactive phase — it's fine to have search results in context here since they're just metadata (titles, authors, snippets).

**Note:** The CLI `--json` flag outputs raw JSON arrays, not objects with a `results` key. Pipe through `jq` carefully — e.g. `jq '.[].title'`, not `jq '.results[].title'`.

## Step 2.5: Update home immediately

Once you know what sources were found, **update `wiki/home.md` right away** — before fetching or ingesting anything. Write a brief overview of what's coming: the topics found, how many sources, what the wiki will cover. This gives the user something to read and shows progress while the import runs.

## Step 3: Fetch into raw/

**Import in small batches.** Fetch and fully ingest 3-5 sources first so the user can see the wiki taking shape before importing more. A wiki with a few well-connected pages is more useful than a queue of unprocessed raws. After the first batch is ingested and the user can browse it, ask if they want to continue with more.

Once the user has picked what to import, delegate to the appropriate skill:

- For **documents**: invoke `fetch-readwise-document` with the selected doc IDs. It handles metadata, streaming the body to disk, and verification.
- For **highlights**: invoke `fetch-readwise-highlights` with the agreed-upon search queries. It handles vector search, deduplication, grouping, and writing highlight files.

Both skills chain into `ingest` automatically to create wiki pages from the raws.

**Important:** All files in `raw/` must be markdown (`.md`), never JSON. Temp JSON files from CLI queries go in `/tmp/`, not `raw/`. If you need to store structured data from Readwise, convert it to a readable markdown document before saving to `raw/`.

## Step 4: Parallel ingest with subagents

**This is the most important performance step.** After fetching raw files, do NOT ingest them one at a time. Use the `Agent` tool to parallelize:

1. **Read the current wiki state yourself first** — read `wiki/index.md` and `wiki/home.md` to understand what exists.
2. **Dispatch one subagent per source** (or per 2-3 related sources) using the `Agent` tool. Launch them all in a single message so they run concurrently. Each subagent brief should include:
   - The path to the raw file(s) to ingest
   - The current wiki index (so it knows what pages exist)
   - The CLAUDE.md schema reference
   - Instructions to: read the raw, create source-summary page, create/update concept pages, cross-link aggressively, update index.md and log.md
3. **After all subagents complete**, do a single pass yourself to:
   - Deduplicate any index.md entries (multiple agents may have added overlapping entries)
   - Update `wiki/home.md` with the full picture
   - Check for cross-linking gaps between the new pages

**Example dispatch pattern:**

```
Agent({
  prompt: "Ingest raw/source-a.md into this wiki. Schema is in CLAUDE.md. Current index: [paste index]. Create source-summary at wiki/sources/, propagate claims to concept pages, cross-link from 2-3 existing pages, update index.md and log.md.",
  description: "Ingest source-a"
})
Agent({
  prompt: "Ingest raw/source-b.md into this wiki. Schema is in CLAUDE.md. Current index: [paste index]. Create source-summary at wiki/sources/, propagate claims to concept pages, cross-link from 2-3 existing pages, update index.md and log.md.",
  description: "Ingest source-b"
})
// ... all in the same message for parallel execution
```

**Why this matters:** Serial ingestion of 5 sources takes 5x as long. Parallel subagents cut wall-clock time dramatically. The dedup pass at the end is cheap.

## Step 5: Update wiki infrastructure

After all subagents complete:

1. Deduplicate `wiki/index.md` entries (multiple subagents may have added the same pages).
2. Update `wiki/home.md` to reflect everything that was imported.
3. Verify `wiki/log.md` has timestamped entries.
4. Scan for cross-linking gaps — pages created by different subagents may not link to each other yet.

Report what was imported and what pages were created.
