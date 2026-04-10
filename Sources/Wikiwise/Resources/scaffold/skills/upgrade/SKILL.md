---
name: upgrade
description: Upgrade this wiki's scaffold files (CLAUDE.md, skills, build tooling) to match the latest Wikiwise app version from GitHub.
---

# Upgrade scaffold

Bring this wiki's scaffold files up to date with the latest Wikiwise release.

## How it works

The file `.claude/scaffold-version` records either a `created:YYYY-MM-DD` date (from initial scaffold creation) or a git commit SHA (from a previous upgrade). This skill fetches the latest scaffold from the Wikiwise GitHub repo, diffs what changed, and applies updates.

If `.claude/scaffold-version` doesn't exist, this wiki predates versioning — treat everything as potentially stale and do a full comparison.

## Step 1: Get the latest commit SHA

```sh
LATEST=$(curl -fsS https://api.github.com/repos/TristanH/wikiwise/commits/main 2>/dev/null \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])" 2>/dev/null)
```

If `python3` is unavailable, use `grep` + `cut`:
```sh
LATEST=$(curl -fsS https://api.github.com/repos/TristanH/wikiwise/commits/main 2>/dev/null \
  | grep '"sha"' | head -1 | cut -d'"' -f4)
```

Read the current version:
```sh
BASE=$(cat .claude/scaffold-version 2>/dev/null || echo "")
```

## Step 2: Determine what changed

### If BASE is a 40-character SHA

Use the GitHub compare API, but filter for **both** scaffold files and build tooling:

```sh
curl -fsS "https://api.github.com/repos/TristanH/wikiwise/compare/${BASE}...${LATEST}" \
  | python3 -c "
import sys, json
files = json.load(sys.stdin).get('files', [])
for f in files:
    name = f['filename']
    if name.startswith('Sources/Wikiwise/Resources/scaffold/') or name.startswith('Sources/Wikiwise/Resources/') and name.count('/') == 4:
        print(name)
"
```

This catches changes to both scaffold templates (`scaffold/CLAUDE.md`, `scaffold/skills/...`) and build tooling (`Resources/build.js`, `Resources/style.css`, etc.).

### If BASE is `created:...` or missing

Do a full comparison — fetch every scaffold and tooling file from GitHub and diff against local copies. See the fetch helper below.

## Fetching files safely

Always download to a temp file first, validate it's not an error response, then move into place:

```sh
fetch_file() {
  local url="$1" dest="$2"
  local tmp=$(mktemp)
  if curl -fsS "$url" -o "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    mv "$tmp" "$dest"
    return 0
  else
    rm -f "$tmp"
    echo "WARN: failed to fetch $url"
    return 1
  fi
}
```

### Scaffold file URLs

Scaffold templates (CLAUDE.md, AGENTS.md, skills, wiki seed files):
```
https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/scaffold/<path>
```

Build tooling (these live outside scaffold/ in Resources/):
```
https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/build.js
https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/style.css
https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/app.js
https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/graph.js
https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/map.html
https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/map-3d.html
https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/markdown-it.min.js
```

## Step 3: Categorize and apply changes

### Safe to overwrite (auto-apply)

These files are tooling or agent instructions that the user doesn't customize:

- `.claude/skills/*/SKILL.md` — skill definitions (overwrite entirely, also add any **new** skills that didn't exist before)
- `site/build.js` — the wiki compiler
- `site/style.css` — the wiki theme
- `site/app.js`, `site/graph.js`, `site/map.html`, `site/map-3d.html`, `site/markdown-it.min.js` — supporting JS/HTML
- `AGENTS.md` — cross-agent instructions
- `llm-wiki.md` — reference document (read-only)

For new skills that didn't exist when the wiki was created, create the directory and download:
```sh
mkdir -p .claude/skills/new-skill-name
fetch_file "${SCAFFOLD_BASE}/skills/new-skill-name/SKILL.md" ".claude/skills/new-skill-name/SKILL.md"
```

### Needs contextual merge (show diff, apply carefully)

These files contain user-specific content and must be merged, not overwritten:

- `CLAUDE.md` — contains the wiki name and possibly user-added rules. Fetch the latest template, show what sections changed, and apply structural changes while preserving the wiki name and any custom additions.

For CLAUDE.md:
1. Fetch the latest template (it has `{{WIKI_NAME}}` as a placeholder)
2. Read the local CLAUDE.md to find the wiki name from the first heading
3. Show the diff of everything **except** the first heading
4. Apply new/changed sections while preserving the wiki name and user additions

### Merge .gitignore entries

`.gitignore` is generated from a string literal in the app, not a scaffold file. Instead of fetching, just ensure these entries exist (append any missing):
```
site/out/
publish.json
.rebuild
```

### Skip — do not fetch or compare

- `.claude/settings.json` — generated from a string literal in the app, not a scaffold file. Only add new entries if you know what the latest settings contain. In practice, settings rarely change.
- `wiki/` — all wiki pages are user content
- `raw/` — immutable source documents

## Step 4: Update the version marker

After applying all changes:

```sh
echo "$LATEST" > .claude/scaffold-version
```

## Step 5: Trigger a rebuild

```sh
touch .rebuild
```

This tells the Wikiwise app to recompile everything with the updated build tooling.

## Step 6: Report

Summarize what was updated:
- Files overwritten (safe updates)
- Files merged (with what changed)
- New skills added
- Any files that failed to fetch or had conflicts

Append to `wiki/log.md`:

```
## [YYYY-MM-DD HH:MM] upgrade | scaffold updated to <short-sha>
```

## Rules

- **Never touch `wiki/` or `raw/` content** — this skill only updates infrastructure.
- **Always show CLAUDE.md changes** before applying — the user may have custom rules.
- **Always trigger `.rebuild`** after upgrading so the app picks up build.js/CSS changes.
- **Always use the safe fetch pattern** — download to temp, validate, then move. Never `curl > target` directly.
- **If no `.claude/scaffold-version` exists**, do a full comparison and let the user review everything. Write the version file after.
