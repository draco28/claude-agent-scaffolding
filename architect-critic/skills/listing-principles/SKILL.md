---
name: listing-principles
description: Show all principles in effect (shipped defaults + user-promoted + project-scoped + memory-bank patterns) grouped by source with annotations. Triggers on "show principles", "list principles", "what principles apply here", "principles in effect", "audit principles". Optional --source all|shipped|user|project filter.
---

# listing-principles

You have been invoked because the user wants to see all principles currently in effect for the architect-critic. Your job is to read up to four principle sources, merge them, apply any `--source` filter, and render the result grouped by source — each principle annotated with its origin and any suppression status. This skill is intentionally read-only: no mutation, no promotion, no state writes.

---

## Step 1: Parse `--source` filter

Read `$ARCHITECT_CRITIC_ARGS` (the env-var bridge the slash-command wrapper exports — do not reference bash positionals `$1`/`$2`, which Claude Code corrupts at template-render time). Extract `--source VALUE` if present; default to `all`.

```bash
SOURCE_FILTER="$(printf "%s" "${ARCHITECT_CRITIC_ARGS:-}" \
  | sed -nE 's/.*--source[= ]+([a-z]+).*/\1/p' | head -1)"
[[ -z "$SOURCE_FILTER" ]] && SOURCE_FILTER="all"
```

Valid values: `all`, `shipped`, `user`, `project`. If the user passes an unrecognized value, treat as `all` and note the fallback inline.

---

## Step 2: Resolve principles sources

You read up to four sources in this exact order. Each is optional except shipped defaults (always present). Document the resolved path for each source in your working context.

**Source 1 — Shipped defaults** (`shipped`)

The plugin ships `templates/principles.md`. It always exists. Locate it using `$CLAUDE_PLUGIN_ROOT`:

```bash
SHIPPED_PATH="${CLAUDE_PLUGIN_ROOT}/templates/principles.md"
```

Contains two load-bearing defaults: the **Ghost Notes principle** (what is absent is often more important than what is present) and the **CORE protocol** (Curiosity → Objectivity → Reassurance → Empathy). Both render under `## Shipped defaults`.

**Source 2 — User-global** (`user`)

```bash
USER_PATH="${HOME}/.claude/architect-critic/principles.md"
```

If this file does not exist, skip this source silently (no "file not found" error in output). If it exists but is empty after stripping headers and blank lines, omit the section header.

**Source 3 — Project-scoped** (`project`)

```bash
PROJECT_PATH="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/architect-critic/principles.md"
```

If `git rev-parse` fails (not in a git repo), try `$PWD/.claude/architect-critic/principles.md`. If the file does not exist, skip this source silently. A project-scoped principle that duplicates a user-global principle is annotated `(overrides user-global)`.

**Source 4 — Memory-bank patterns** (`project` filter includes these; `all` includes these)

Only available if scaffold-onboard is installed. Probe the filesystem:

```bash
SCAFFOLD_INSTALLED="$(ls ~/.claude/plugins/*/scaffold-onboard/skills/ 2>/dev/null | head -1)"
```

If `SCAFFOLD_INSTALLED` is non-empty, load `$(git rev-parse --show-toplevel 2>/dev/null)/.claude/memory-bank/patterns.md` if it exists. These entries render under `## Memory-bank patterns` and count as project-source for filter purposes.

---

## Step 3: Merge via the `arc` dispatcher

Call the bash helper to load user-global principles. The `arc` dispatcher is on `$PATH` (Claude Code adds each plugin's `bin/` automatically); the dispatcher's bash shebang forces a bash runtime under it regardless of the calling Bash tool's shell (zsh by default on macOS), so the lib's `${BASH_SOURCE[0]}` and `${BASH_REMATCH[…]}` work as written. Never `source` the lib directly from skill body — under zsh it crashes:

```bash
arc principles_load_user_global
```

This strips header lines (lines starting with `# `), strips trailing `[promoted ...]` annotations, and emits one active principle per line. Hold the output in your working context.

For the shipped defaults and project-scoped file, read them directly with the Read tool (they use `<!-- source: ... -->` HTML comments that you parse — see Step 5 below). For memory-bank patterns, read the file directly if it exists.

**Duplicate handling.** Normalize for comparison: trim, lowercase, collapse spaces. Project-scoped wins over user-global on conflict; annotate the winner `(overrides user-global)`. Drop the duplicate silently. Display order: shipped → user → project → memory-bank.

---

## Step 4: Apply `--source` filter

| Filter value | Sources shown |
|---|---|
| `all` | shipped + user + project + memory-bank |
| `shipped` | shipped only |
| `user` | user-global only |
| `project` | project-scoped + memory-bank (both live in the repo) |

Apply the filter after the merge. Do not re-read files; just drop sections not matched by the filter before rendering.

---

## Step 5: Read suppressions

Read `auto_promote_suppressions[]` from `state.json`:

```bash
STATE_FILE="${HOME}/.claude/architect-critic/state.json"
SUPPRESSIONS="$(jq -c '.auto_promote_suppressions // []' "$STATE_FILE" 2>/dev/null || echo '[]')"
NOW_ISO="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
```

A suppression is **active** if its `expires_at` field is greater than `NOW_ISO` (lexicographic ISO8601 comparison is correct). Collect all active suppressions into a working list.

These are declined auto-promotion candidates; surfacing them lets the user know why a recurring theme isn't appearing as a candidate. Display in a `## Suppressed candidates` footer. If the field is absent or empty, skip the footer silently.

---

## Step 6: Render output

Render as markdown in your turn message. Group by source heading. Omit any section whose source produced zero entries after filtering — do not render empty headers.

### `<!-- source: ... -->` HTML comment contract

The shipped `templates/principles.md` and any project/user principles files may annotate lines with inline HTML comments:

```
- **Ghost Notes principle**: what is absent...  <!-- source: shipped-default -->
- **Prefer explicit over implicit** <!-- source: user-promoted, promoted: 2026-05-22 -->
- **Use 2-space indent** <!-- source: project, promoted: 2026-05-20 -->
```

Parse the comment values:
- `source: shipped-default` → place under `## Shipped defaults`
- `source: user-promoted, promoted: DATE` → `## Your principles (user-promoted)`, append `— promoted DATE`
- `source: project, promoted: DATE` → `## Project principles`, append `— promoted DATE`

Strip the HTML comment from display text. This is the contract Phase 3.2 (auto-promotion write path) relies on. `ac_principles_load_user_global` strips `[promoted ...]` bracket annotations for the merge step; HTML comments are preserved in raw files for display here.

### Rendered format

```
## Shipped defaults
- **Ghost Notes principle**: what is absent from the spec is often more important than what is present <!-- source: shipped-default -->
- **CORE protocol**: Curiosity → Objectivity → Reassurance → Empathy <!-- source: shipped-default -->

## Your principles (user-promoted)
- **Prefer explicit over implicit configuration** — promoted 2026-05-22 <!-- source: user-promoted -->

## Project principles
- **Use 2-space indent** — promoted 2026-05-20 <!-- source: project -->

## Memory-bank patterns
- **Avoid mutable shared state across async boundaries** (from .claude/memory-bank/patterns.md)

## Suppressed candidates (won't auto-promote until expiry)
- "Use camelCase for variables" — suppressed 2026-05-01, expires 2026-05-31 (reason_score 4)
```

---

## Step 7: Empty-state handling

| Condition | Output |
|---|---|
| Only shipped defaults exist | Render shipped section; omit user/project/memory-bank/suppressed sections |
| `--source user` with no user principles | "No user-promoted principles yet. Run `/promote-principle` to add one." |
| `--source project` with no project file | "No project-scoped principles file found at `.claude/architect-critic/principles.md`." |
| `--source shipped` | Always renders (shipped file always present) |
| All sources empty (impossible — shipped always present) | Render shipped section with its defaults |

Do not output empty section headers. A one-liner message is better than a header with nothing under it.

---

## Worked example

Suppose:
- Shipped `templates/principles.md` has Ghost Notes + CORE.
- `~/.claude/architect-critic/principles.md` has one user-promoted principle: *"Prefer explicit over implicit configuration"* (promoted 2026-05-22).
- `.claude/architect-critic/principles.md` has one project principle: *"Use 2-space indent for all YAML/JSON config"* (promoted 2026-05-20).
- scaffold-onboard is not installed (no memory-bank source).
- `state.json` has one active suppression: *"Use camelCase for variables"* (suppressed 2026-05-01, expires 2026-05-31, reason_score 4).

With `--source all` (default), the rendered output is:

---

## Shipped defaults
- **Ghost Notes principle**: what is absent from the spec is often more important than what is present <!-- source: shipped-default -->
- **CORE protocol**: Curiosity → Objectivity → Reassurance → Empathy as the tone for every challenge raised <!-- source: shipped-default -->

## Your principles (user-promoted)
- **Prefer explicit over implicit configuration** — promoted 2026-05-22 <!-- source: user-promoted -->

## Project principles
- **Use 2-space indent for all YAML/JSON config** — promoted 2026-05-20 <!-- source: project -->

## Suppressed candidates (won't auto-promote until expiry)
- "Use camelCase for variables" — suppressed 2026-05-01, expires 2026-05-31 (reason_score 4)

---

With `--source shipped`, only the shipped section renders. With `--source user` and one principle present, the suppressed footer is omitted (suppressions are cross-source metadata, shown only under `all`).

---

## Tool boundary and Phase 3.2 contract

All file I/O (principles files, state.json, scaffold-onboard probe) runs in Bash. Merge logic and display assembly run in your working context. The render is your turn message as plain markdown — not bash stdout, not a tool-call trace. Do not mutate any file. This skill is read-only.

The following documents the comment format so Phase 3.2 (auto-promotion write path in `critiquing-spec` + `promoting-principle`) can round-trip correctly.

When `lib/promotion.sh` or `promoting-principle` writes a new principle to a principles.md file, it appends a line of this form:

```
- <principle text>  <!-- source: user-promoted, promoted: YYYY-MM-DD -->
```

or for project-scoped:

```
- <principle text>  <!-- source: project, promoted: YYYY-MM-DD -->
```

When `listing-principles` reads a file back:
1. Strip the HTML comment from the display text.
2. Parse `source:` to determine which heading the entry belongs under.
3. Parse `promoted: DATE` to render the `— promoted DATE` annotation.
4. Pass the stripped text to `ac_principles_load_user_global` for the merge step (that function already strips `[promoted ...]` bracket annotations; it does not strip HTML comments — so callers of `ac_principles_load_user_global` get the comment-free merge result when the file uses bracket-style annotations, and the HTML comment path is handled here at display time).

**Backward compatibility.** v0.1.x files use bracket annotations `[promoted DATE source:SCOPE]` instead of HTML comments. Recognize both forms and render both as `— promoted DATE`. HTML comments are the v0.2 canonical form; brackets are accepted for graceful migration.
