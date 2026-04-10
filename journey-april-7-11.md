---

# The Week I Built WikiWise

**April 8--10, 2026**

---

## Wednesday Afternoon: Standing Up the Wiki

The whole thing started Wednesday after lunch. At 2:19pm I made the initial commit: a meta-wiki about Karpathy's LLM wiki pattern, using the LLM wiki pattern itself. Two seed sources -- Karpathy's gist and a Slack thread where the team had been riffing on related ideas. A schema in CLAUDE.md. Raw sources in `raw/` (read-only), wiki pages in `wiki/` (LLM-maintained).

The first structural decision came quickly. I'd started with subdirectories -- `concepts/`, `entities/`, `sources/` -- but Karpathy's actual pattern is flat. Everything sits at the wiki root except source summaries. I flattened it and added a "Deviations from Karpathy" section to CLAUDE.md to track every conscious departure from his design. That section turned out to be one of the most valuable parts of the project: it forced me to know what was his and what was mine.

The first painful lesson also came fast. I tried to have Claude pull documents from my Readwise library and write them as source files. Agonizingly slow -- subagents wrote to wrong directories, parallel batches got killed. I kept interrupting. That failure directly produced one of the week's best ideas: the `fetch-readwise-source` skill, which pipes content from the Readwise CLI straight to disk via `jq`, never loading anything into Claude's context. The fastest way to move data is to not look at it.

By Wednesday evening I had an Obsidian-style graph view working, a split-pane preview on node click, and was ingesting sources about sensemaking and second-brain-as-a-service. I was also writing wiki pages about "what people still pay for" in the age of vibe-coding. The strategic question that had been nagging me for weeks -- where does Readwise fit when the plumbing layer commoditizes? -- was starting to take shape on the page.

Somewhere in there I had a long strategic brainstorming session. The breakthrough was the Monologue analogy: Monologue and Whisperflow are transcription apps, same underlying tech, trivially vibe-codeable. But Whisperflow found an acquisition verb by being a standalone mobile app with polished UX. I called this the "Monologue-shaped bet" -- the idea that Readwise's PKM 2.0 play might look like a simple, beautiful, standalone thing that happens to be backed by your entire reading history.

Claude kept trying to converge during this session. "Let's commit to a direction." I had to push back repeatedly: "You're projecting a lot of certainty." "I need a tinkering mindset, not a strategist mindset." That friction recurred all week -- Claude wanting to close and me wanting to stay open.

Late Wednesday night I designed the app in Paper. The aesthetic I landed on was editorial/library: warm cream background (#f6f1e7), Fraunces italic for display type, Newsreader for body text, JetBrains Mono for labels. Three columns -- file explorer left, article center, metadata right. The key design moment was the FILE | WIKI toggle: instead of the app having two modes, each file toggles between raw markdown and compiled wiki view. Wiki-ness is a property of the file, not a state. Publishing is a button, not a mode switch. That resolved a tension I'd written about explicitly in a commit that evening: "markdown-app vs. wiki-website architectural tension."

I also researched what to fork. Almost every wiki-shaped markdown app is copyleft (AGPL/GPL). MarkEdit was the most interesting reference: a Swift + WKWebView hybrid using CodeMirror 6. That architecture turned out to be what I built. I tested WhisperKit for point-and-talk -- first call 15.5 seconds (cold), subsequent calls ~100ms. Good enough warm, but cold start was a problem.

By the time I stopped, I'd shaped the requirements: open a folder of markdown, read pleasantly, edit by pointing and talking, wikilinks resolve, Mac-native feel.

## Thursday: The Insane Day

Thursday April 9 was 111 commits. The entire app -- from first source file to working product with 19 merged PRs -- in a single day.

**Morning (8:40am--11:47am):** Ingested 12 more raws (Slack day 2 + 11 tweets). Renamed `site/` to `v1_site/` to make room. Added the OpenReader source files at 11:31am. By 11:47am I had v1 feature parity: graph view, search, wikilink hover popovers, backlinks, callouts, nav rail, masthead. All ported from the Python-built v1 site into a SwiftUI + WKWebView + JavaScriptCore architecture. The JavaScript compiler (markdown-it + plugins) runs in JavaScriptCore with Swift providing file I/O functions. I rejected requiring Node.js -- a desktop app needs bundled dependencies.

**Midday (12:00--2:30pm):** Refactored variable names. Pixel-sampled a screenshot to get the sidebar divider color (#c9c9c9) matching the system component. Fixed three XSS vulnerabilities. Merged PR #1 (v1 parity, 706 lines). Got incremental compilation working -- 5.2x speedup, 2309ms down to 446ms with mtime-based caching. Integrated the map view. Added CodeMirror for the Raw editing tab with auto-save on a 500ms debounce.

The CodeMirror integration produced the scariest bug of the week: auto-save fired before the editor loaded content, writing empty string to disk. It wiped `home.md` to 0 bytes. Fixed it with an empty-content guard.

**Afternoon (2:30--5:00pm):** Adopted the Paper design: Fraunces/Newsreader/JetBrains Mono fonts, warm cream palette, custom folder icons. Built the "Create New Wiki" scaffold flow -- press a button and it creates CLAUDE.md, `.claude/skills/`, `wiki/` with seed files, `site/` with `build.js`. Added AGENTS.md for Cursor/Codex/Windsurf compatibility. Iterated on toolbar layout for what felt like forever -- back/forward buttons, sidebar toggle, FILE/WIKI toggle, folder name centering. SwiftUI toolbar positioning is essentially uncontrollable; I must have done ten commits just moving buttons around.

Merged PRs #3 (map), #4 (incremental compilation), #5 (ingest-topic skill), #6 (CodeMirror), #7 (Paper design), #8 (wiki scaffold), #9 (responsive layout), #10 (nav buttons).

**Evening (5:00--9:00pm):** Built progressive rendering for large workspaces (compile on demand instead of up front). Built the right sidebar with SwiftTerm embedded terminal and an info tab. This is where I discovered that SwiftPM build caching causes ghost UI duplicates -- old views literally haunt the app after code changes. Cost me hours before I figured out: always `swift package clean` before builds. Fixed the phantom sidebar icon. Fixed the janky resize drag.

Built the active-file context system: the Swift app writes the currently-open file to `.claude/active-file`, and a hook reads it so Claude knows what you're looking at. Small feature, big deal for the agent workflow.

Split the import-readwise skill into three: an orchestrator plus two fetch primitives. Fixed wiki search by inlining search data as `<script>` tags instead of `fetch()` (which doesn't work on `file://` URLs in WKWebView). Parsed YAML frontmatter into subtitle + infobox tables. Tightened the TOC rail.

**Night (9:00pm--midnight):** Kept going. Added `wiki/sources/` directory support, dynamic masthead, sidebar sort and tooltips. Fixed the digest skill that got accidentally deleted. Capped page widths. Included Karpathy's `llm-wiki.md` in the scaffold so every new wiki starts with the reference.

PRs #11 through #19 all merged Thursday.

At midnight I started writing the publish-to-wikiwise spec.

## Friday: Publish, Polish, Multiply

**Early hours (12:23am--1:00am):** Built the full publish pipeline. Cloudflare Workers + R2. Each wiki gets a randomized subdomain on wiki-wise.com. The domain is the password for now -- no auth beyond an unguessable URL. Token auth on the upload endpoint, file size caps, reserved subdomains. Deployed the Worker, smoke-tested, it worked.

**Morning (Friday Apr 10):** Dark mode with a three-way toggle (light/dark/auto), Paper-derived color scheme applied to both SwiftUI and CSS. Redesigned the masthead as a drop-cap with stacked monospace words. Fixed the publish domain (wiki-wise.com, not wikiwise.com -- that was taken). Cleaned up build artifacts that got committed accidentally.

Then I split the repo. Moved the app to TristanH/wikiwise as a standalone project. Did it, reverted it, reapplied it -- git surgery on a Friday. Added GPLv3 license, release build script with signing and notarization, Codex support, the `.rebuild` trigger for agent-driven recompilation, and an `/upgrade` skill for updating old wikis to the latest scaffold.

**The rest of Friday: multiplying.** I'd built WikiWise as a tool for making wikis, so I used it to make more wikis:

- **startup-strategies** -- 82 pages synthesizing 7 Powers, Zero to One, Cold Start Problem, Crossing the Chasm, and ~30 other sources from my Readwise library. Zero broken wikilinks. Built a retro SGI-style 3D map alongside the standard graph.
- **ai-coding** -- 18 concept pages from Willison, Karpathy, singleton.io on agentic engineering and coding agents.
- **claude-mythos** -- 15 pages on Claude's 70,000-word system card, Project Glasswing, model welfare, Dario's essays.
- **current-things** -- YouTube transcripts + tools-for-thought classics. Memey pages about pig skyscrapers alongside Xanadu and Memex.
- **marathon-training** -- just starting, Hansons Marathon Method highlights imported.

Each wiki taught me something about the scaffold. I kept fixing import skills, log ordering, metadata styling. By Friday the scaffold was creating wikis that looked right out of the box.

**Parallel track: RAILS v2.** In a separate repo, I also rewrote the Claude Code Slack bot deployment system. 165 tests, all passing. Codex code review found real bugs (shell injection, mention stripping). Three parallel review agents independently recommended the same simplification: delete commands.js, actions.js, heartbeat.js -- push logic to the agent, keep the listener dumb. ~3,000 lines down to 982.

**Parallel track: the refounding.** I used Claude as a sparring partner for difficult team 2:1s. Revenue is shrinking. I wrote conversation scripts for four people, each structured around productivity/proactivity/adaptability. Claude named two patterns: "declining the dragon" (knowing people need to go but not acting) and "gutterballing" (spending weeks on people management instead of product). Both landed.

---

## What I Learned

**The pipe-to-disk pattern is load-bearing.** The best architectural decision of the week was building skills that move data without loading it into context. The lesson generalizes: separate transport from cognition.

**SwiftUI lies about being declarative.** NavigationSplitView duplicates toolbar items across columns. Build caching causes ghost UI. The WKWebView escape hatch -- where I control the HTML directly -- was more reliable than the "native" components.

**Claude is better at building than at deciding.** Every strategic conversation, it tried to converge too fast. But when I gave it a shaped requirement and said "build this," it was extraordinary. The publish pipeline went from spec to working in a single session. Shape first, then hand over.

**Multiplying is the proof.** Building one wiki is a project. Building six in a week is a tool. The moment I started using WikiWise to make other wikis, the tool disappeared. I was just reading and thinking.

**The acquisition question is still open.** I built a tool power users would love and still don't have a clean answer for how someone new finds it. The Monologue analogy is the best frame I have. But "build a beautiful standalone thing" is a description, not a strategy.

---

## Token Usage

### Daily Totals

| Day | Sessions | API Calls | Cache Read | Cache Write | Input | Output | Total |
|-----|----------|-----------|------------|-------------|-------|--------|-------|
| Mon Apr 7 | 18 | 1,000 | 237.4M | 17.0M | 8K | 295K | 254.7M |
| Tue Apr 8 | 56 | 4,475 | 491.4M | 44.4M | 197K | 1.7M | 537.8M |
| Wed Apr 9 | 18 | 4,350 | 794.0M | 18.4M | 45K | 1.9M | 814.3M |
| Thu Apr 10 | 98 | 8,366 | 1,295.0M | 31.9M | 55K | 2.8M | 1,329.8M |
| **Total** | **180** | **18,191** | **2,817.8M** | **111.7M** | **305K** | **6.8M** | **2,936.6M** |

**~2.94 billion tokens. 18,191 API calls. 180 sessions.**

96% of tokens are cache reads -- the conversation context getting re-sent on each turn but hitting the prompt cache. Output tokens are a rounding error at 6.8M.

### By Project

| Project | API Calls | Total Tokens |
|---------|-----------|-------------|
| wikiwise (wiki content) | 9,827 | 1,813M |
| wikiwise-app (Swift app) | 4,064 | 591M |
| RAILS v2 (Slack bot) | 458 | 186M |
| ai-hack-w2 (hackathon) | 609 | 97M |
| startup-strategies wiki | 772 | 77M |
| sidebar phantom icon fix | 917 | 74M |
| rekindled (Reader bugs) | 472 | 40M |
| claude-mythos wiki | 195 | 21M |
| startup-strategy wiki | 352 | 13M |
| current-things wiki | 131 | 10M |
| ai-coding wiki | 232 | 8M |
| the-goal (refounding) | 31 | 1.4M |
| others | 131 | 5M |

WikiWise (wiki + app + worktrees) accounts for 84% of all usage at 2.48B tokens.

### Estimated Cost

Assuming all Opus (upper bound): **~$6,800.** The cache-read dominance keeps this surprisingly low -- 2.8B cache-read tokens at $1.50/MTok is ~$4,200, while the 6.8M output tokens at $75/MTok is only ~$510. If some sessions used Sonnet, the real number is lower, maybe $4,000--5,000.

---

*194 commits. 22+ merged PRs. 6 wikis. 3 custom skills. 1 published site. ~2.94 billion tokens. 3 days.*
