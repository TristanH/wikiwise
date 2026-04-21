---
name: ingest-tweets
description: Search Twitter/X for tweets on a topic using browser automation (Claude for Chrome or Chrome DevTools MCP), extract the content, and ingest it into the wiki as a source.
---

# Ingest tweets on a topic

Use browser automation to search Twitter/X for tweets about a topic the user specifies, extract the interesting ones, and run them through the standard ingest pipeline.

## Prerequisites

The user must have **one** of these browser MCP tools available:

- `mcp__claude-in-chrome__*` (Claude for Chrome extension)
- `mcp__chrome-devtools__*` (Chrome DevTools MCP server)

Detect which is available by checking for either toolset. If neither is present, tell the user they need a browser automation MCP connected and stop.

## Step 1 — Open Twitter search

Navigate to Twitter/X search for the user's topic:

```
https://x.com/search?q=<url-encoded-query>&src=typed_query&f=top
```

Use `f=top` (Top tweets) by default. If the user asks for recency, use `f=live`.

Wait for the page to load and the tweet feed to render.

## Step 2 — Read and scroll the feed

Read the visible tweets from the page. Each tweet needs:

- **Author** — display name and @handle
- **Date** — timestamp
- **Text** — full tweet body (expand "Show more" if truncated)
- **Engagement** — likes, retweets, replies (rough numbers are fine)
- **URL** — `https://x.com/<handle>/status/<id>`

Scroll down 2-3 times to collect more tweets. Aim for **10-20 tweets** unless the user specified a different amount.

If Twitter shows a login wall or CAPTCHA, stop and tell the user — they need to be logged in on that browser.

## Step 3 — Curate

Present the collected tweets to the user as a numbered list with author, date, and a one-line summary of each. Ask which ones to ingest, or confirm "all" if the user said to grab everything.

## Step 4 — Save to raw/

Write a single raw file at `raw/tweets_<topic-slug>_<YYYY-MM-DD>.md` containing all selected tweets in this format:

```markdown
# Tweets: <Topic>

**Collected:** YYYY-MM-DD HH:MM
**Query:** <the search query used>
**Source:** https://x.com/search?q=<query>

---

## @handle — YYYY-MM-DD

> Full tweet text here, preserving line breaks.

Likes: N · Retweets: N · Replies: N
Source: https://x.com/handle/status/id

---

## @handle2 — YYYY-MM-DD

> Next tweet...

...
```

## Step 5 — Ingest

Invoke the `ingest` skill on the raw file. The source-summary page should:

- Use `type: tweets` in frontmatter.
- Summarize the overall discourse — what are people saying, where do they agree/disagree, what's the dominant take vs. contrarian takes.
- Attribute specific claims to specific authors with tweet URLs.

## Tips

- **Thread detection:** If a tweet is part of a thread (reply chain from the same author), try to grab the full thread by clicking into it and reading the chain. Note it as a thread in the raw file.
- **Quote tweets:** Include the quoted tweet inline, indented, so the context is preserved.
- **Images/media:** Note `[image]`, `[video]`, or `[link preview: <url>]` inline — don't try to download media.
- **Multiple searches:** If the topic is broad, the user may want you to run multiple queries (e.g., the topic name, key people associated with it, related hashtags). Ask if one query is enough or if they want to cast a wider net.

## Rules

- **Never** fabricate tweets. Only include content actually visible on the page.
- **Never** `Read` a `raw/` file you just wrote unless the user asks.
- **Stop and ask** if fewer than 3 tweets are found — the topic may need a different query.
- **Respect the user's curation choices** in Step 3 — don't silently drop or add tweets.
