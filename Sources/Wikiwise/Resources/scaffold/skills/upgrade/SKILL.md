---
name: upgrade
description: Upgrade this wiki's scaffold files (CLAUDE.md, skills, build tooling) to match the latest Wikiwise app version from GitHub.
---

# Upgrade scaffold

Bring this wiki's scaffold files up to date with the latest Wikiwise release.

## How it works

The file `.claude/scaffold-version` records the git commit SHA this wiki was created from (or last upgraded to). This skill fetches the latest scaffold from the Wikiwise GitHub repo, diffs what changed, and applies updates.

## Step 1: Read the current version

```sh
cat .claude/scaffold-version
```

The file contains either:
- `created:YYYY-MM-DD` — date-based (from initial scaffold creation)
- A 40-character git commit SHA (from a previous upgrade)

If the file doesn't exist, this wiki predates versioning. Treat everything as potentially stale — skip to step 2b.

## Step 2: Fetch the latest scaffold

### 2a: If you have a commit SHA

Use the GitHub compare API to get exactly what changed in the scaffold:

```sh
LATEST=$(curl -s https://api.github.com/repos/TristanH/wikiwise/commits/main | grep '"sha"' | head -1 | cut -d'"' -f4)
BASE="<the SHA from scaffold-version>"

curl -s "https://api.github.com/repos/TristanH/wikiwise/compare/${BASE}...${LATEST}" \
  | python3 -c "import sys,json; [print(f['filename']) for f in json.load(sys.stdin).get('files',[]) if f['filename'].startswith('Sources/Wikiwise/Resources/scaffold/')]"
```

This gives you the exact list of scaffold files that changed. Only process those files.

### 2b: If you have a date or no version

Fetch the latest version of each scaffold file and compare against the local copy. Use `diff` to check what changed:

```sh
SCAFFOLD_BASE="https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/scaffold"

# Fetch and compare a file
curl -s "${SCAFFOLD_BASE}/CLAUDE.md" > /tmp/latest-CLAUDE.md
diff CLAUDE.md /tmp/latest-CLAUDE.md
```

Do this for each file category (skills, build tooling, CLAUDE.md, AGENTS.md). If they're identical, skip. If they differ, apply per the rules in step 3.

### Fetching individual files

```sh
curl -s "https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/scaffold/<path>"
```

For build tooling files that live outside the scaffold in the repo:
```sh
# These are copied from Resources/, not Resources/scaffold/
curl -s "https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/build.js"
curl -s "https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/style.css"
curl -s "https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/app.js"
curl -s "https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/graph.js"
curl -s "https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/map.html"
curl -s "https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/map-3d.html"
```

## Step 3: Categorize and apply changes

### Safe to overwrite (auto-apply)

These files are tooling or agent instructions that the user doesn't customize:

- `.claude/skills/*/SKILL.md` — skill definitions (overwrite entirely, also add any new skills)
- `site/build.js` — the wiki compiler
- `site/style.css` — the wiki theme
- `site/app.js`, `site/graph.js`, `site/map.html`, `site/map-3d.html` — supporting JS/HTML
- `AGENTS.md` — cross-agent instructions
- `llm-wiki.md` — reference document (read-only)
- `.gitignore` — merge new entries (append lines that don't already exist)

For each safe file, fetch the latest version and overwrite:

```sh
curl -s "https://raw.githubusercontent.com/TristanH/wikiwise/main/Sources/Wikiwise/Resources/scaffold/skills/ingest/SKILL.md" \
  > .claude/skills/ingest/SKILL.md
```

### Needs contextual merge (show diff, apply carefully)

These files contain user-specific content and must be merged, not overwritten:

- `CLAUDE.md` — contains the wiki name and possibly user-added rules. Fetch the latest template, show the user what sections changed (ignoring the `{{WIKI_NAME}}` placeholder), and apply the structural changes while preserving the wiki name and any custom additions.
- `.claude/settings.json` — may have user-added hooks or permissions. Merge new entries.

For CLAUDE.md specifically:
1. Fetch the latest template from GitHub
2. Show the diff between the template and the local file (ignoring the first heading which has the wiki name)
3. Apply new/changed sections while preserving the wiki name in the heading and any user-added content

### Skip (user content, never touch)

- `wiki/` — all wiki pages are user content
- `raw/` — immutable source documents
- `wiki/home.md`, `wiki/index.md`, `wiki/log.md` — even the seed files, once created

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
- Any files skipped or conflicts encountered

Append to `wiki/log.md`:

```
## [YYYY-MM-DD HH:MM] upgrade | scaffold updated to <short-sha>
```

## Rules

- **Never touch `wiki/` or `raw/` content** — this skill only updates infrastructure.
- **Always show CLAUDE.md changes** before applying — the user may have custom rules.
- **Always trigger `.rebuild`** after upgrading so the app picks up build.js/CSS changes.
- **If no `.claude/scaffold-version` exists**, do a full comparison and let the user review everything. Write the version file after.
