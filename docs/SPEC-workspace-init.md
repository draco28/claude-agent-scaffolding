# SPEC: workspace-init plugin

**Status:** v0.1 — brainstorm settled 2026-05-20; **adversarial-review revisions applied 2026-05-22**. Awaiting PLAN authoring.
**Owner:** Praveen Kumar Singh
**Repo home:** `claude-agent-scaffolding` marketplace
**Position:** First plugin in the marketplace chain — `workspace-init` → `scaffold-onboard` → `scaffold-dev` → `architect-critic` + `ai-mentor`
**Platforms:** Linux, macOS (Windows deferred)
**Version history:** v0.1 (initial design); 2026-05-22 revisions per spec-review pass (no version bump — pre-build refinement)

---

## 1. TL;DR

A run-once Claude Code plugin that bootstraps a **dual-repo workspace** — an AI workspace (git-tracked repo holding all AI scaffolding) paired with a canonical repo (production code only, zero AI traces visible in engineering history). Runs in a parent directory, takes a project name (and optionally a path to an existing canonical), creates both repos with appropriate skeletons, writes a JSON pairing manifest at `<ai-workspace>/.workspace/pairing.json`, installs a `commit-msg` git hook in both repos that prevents AI-trace leaks, and exits with next-steps guidance.

Skill-first surface (per Pass D); the plugin's slash commands are thin wrappers for explicit invocation.

---

## 2. Motivation

**P1 — AI traces in commit history aren't acceptable on work-laptop projects.** Claude Code adds `Co-Authored-By: Claude <noreply@anthropic.com>` trailers; Codex CLI adds analogous trailers; some flows include 🤖-marker lines. For work projects, traces are unshareable. The user has previously blocked all agent-initiated commits to avoid the leak. A guardrail preventing AI-trace patterns from landing in commit messages unlocks AI-assisted local commits without compromising canonical history.

**P2 — Worktree state divergence in single-repo setups blocks parallel slice work.** When `.claude/`, `CLAUDE.md`, and memory-bank live alongside production code (typically gitignored), `git worktree add` for a parallel branch starts cold. The dual-repo split moves AI scaffolding into a separate repo that's never worktreed; canonical worktrees stay clean and inherit nothing.

**P3 — Sprint orchestration with parallel slices needs structural separation.** scaffold-dev's orchestrator-implementer split only works cleanly when AI workspace and canonical are distinct git boundaries.

**P4 — scaffold-onboard's outputs cross a real semantic line.** MASTER-SPEC.md, memory-bank files, CLAUDE.md are agent scaffolding (AI workspace). PRD.md, SRS.md, BACKLOG.md, ADRs are production docs (canonical). Dual-repo + routing table makes the split mechanical.

---

## 3. Goals & non-goals

### Goals

- **G1.** Bootstrap a fully-paired dual-repo workspace in a single guided invocation.
- **G2.** Write the pairing manifest as a stable v1.0 schema that serves as cross-plugin coordination contract.
- **G3.** Strict AI-trace prevention via a `commit-msg` git hook installed in both repos.
- **G4.** Ship skill-first from day 1 (per Pass D).
- **G5.** Loose coupling for complementary plugins (architect-critic, ai-mentor) — manifest is a discovery hint.
- **G6.** Support pairing with existing canonical via `--pair-with <path>` (Scenario A).

### Non-goals

- NG1. Scenario B migration (split existing scaffold-onboard'd single-repo). Deferred to v0.2.
- NG2. Automatic git remote setup. Deferred to v0.2.
- NG3. User-global workspace registry. Deferred to v0.2.
- NG4. Memory-bank or MASTER-SPEC authoring (scaffold-onboard's job).
- NG5. Sprint/slice orchestration, worktree spawning, implementation handoffs (scaffold-dev's job).
- NG6. Cognitive-mode enforcement (ai-mentor's job).
- NG7. Cross-machine state synchronization.

---

## 4. Architecture overview

### 4.1 Position in marketplace

(Per §1 — workspace-init runs FIRST in the chain. Manifest it writes is consumed by everything downstream.)

### 4.2 Coupling tiers

| Plugin | Coupling | Behavior when manifest absent |
|---|---|---|
| `workspace-init` | writes manifest | n/a |
| `scaffold-onboard` v0.2 | tight read | falls back to single-repo mode (today's v0.1.0 behavior) |
| `scaffold-dev` v0.1 | tight read | refuses to start; points user at workspace-init |
| `architect-critic` v0.2 | loose read | uses standalone discovery (`--spec PATH` or heuristic); manifest is fast-path when present |
| `ai-mentor` | none | unaffected |

### 4.3 The dual-repo topology

```
~/projects/foo-ai/                      # AI workspace (git-tracked, ~once-per-sprint commits)
├── .workspace/
│   ├── pairing.json                    # the manifest
│   ├── init-log                        # transactional log of init operations (rollback support)
│   └── handoffs/                       # scaffold-dev creates here (gitignored; per scaffold-dev §6b handoff escape valve)
├── .claude/
│   ├── memory-bank/                    # scaffold-onboard authors here
│   └── .onboarding-state.json          # gitignored
├── docs/
│   ├── MASTER-SPEC.md                  # scaffold-onboard authors
│   ├── specs/                          # scaffold-dev authors sprint specs here
│   ├── process-adrs/                   # agent-workflow ADRs (split from product ADRs)
│   └── superpowers/                    # brainstorm specs
├── .superpowers/brainstorm/            # brainstorm artifacts (tracked)
├── .archive/                           # soft-deleted (Wabash convention)
├── CLAUDE.md                           # session-start router (scaffold-onboard overwrites stub)
├── AGENTS.md                           # cross-tool agents
├── README.md
└── .gitignore

~/projects/foo/                         # canonical (git-tracked, per-feature/slice/bug-fix commits)
├── src/                                # production code (user authors)
├── tests/
├── docs/                               # human-style production docs
│   ├── PRD.md                          # scaffold-onboard authors
│   ├── SRS.md
│   ├── BACKLOG.md
│   ├── PROJECT_PLAN.md
│   ├── EXECUTIVE-SUMMARY.md
│   ├── adr/                            # product ADRs
│   └── (other governance docs as scaffold-onboard generates)
├── .worktrees/                         # scaffold-dev creates worktrees here
└── .git/hooks/commit-msg               # workspace-init installs (only modification to canonical's working state)
```

---

## 5. Skills & commands

Per Pass D: primary surface is skills with description-matched triggers; slash commands are thin wrappers.

### 5.1 Skill: `initializing-dual-repo-workspace`

**Path:** `workspace-init/skills/initializing-dual-repo-workspace/SKILL.md`

```yaml
---
name: initializing-dual-repo-workspace
description: Bootstrap a fresh dual-repo workspace — creates a new AI workspace repo (memory bank, specs, agent scaffolding) and a clean canonical repo (production code, zero AI traces) with a pairing manifest. Use when the user wants to start a new project with the dual-repo topology, mentions "create workspace", "bootstrap project", "new AI workspace", "set up dual repo", "init project workspace".
---
```

Body outline (≥150, ≤500 lines): take inputs → validate → execute 8 pre-onboard tasks (§8) → print next-steps. Calls bash bookkeeping scripts in `lib/`.

### 5.2 Skill: `pairing-canonical-repo`

**Path:** `workspace-init/skills/pairing-canonical-repo/SKILL.md`

```yaml
---
name: pairing-canonical-repo
description: Pair a new AI workspace with an existing canonical repository (Scenario A migration). Creates the sibling AI workspace and writes a manifest pointing at existing canonical. Does NOT modify the existing canonical except for installing the commit-msg hook. Use when user has existing repo without AI scaffolding and wants to add an AI workspace alongside.
---
```

### 5.3 Slash command wrappers

| Wrapper | Wraps | Usage |
|---|---|---|
| `/init-workspace [name]` | `initializing-dual-repo-workspace` | `/init-workspace foo` |
| `/pair-workspace <existing-canonical>` | `pairing-canonical-repo` | `/pair-workspace /abs/path/foo` |
| `/pair-existing-dual <ai-ws> <canonical>` | `pairing-existing-dual` (Scenario C, §9.5) | `/pair-existing-dual /abs/path/ws /abs/path/canon` |

All use the `$ARGUMENTS` env-var bridge (per `feedback_slash_command_dollar_n_bug` memory).

---

## 6. The pairing manifest

### 6.1 Path & discovery

**Path:** `<ai-workspace>/.workspace/pairing.json`

**Discovery from AI workspace:** plugins walk up from `$PWD` looking for `.workspace/pairing.json`; cache discovered path per session.

**Discovery from canonical:** **no walk-up** (siblings, not ancestors). Canonical's `.git/hooks/commit-msg` has the AI workspace path baked in at install time (per §7.3). Hook reads manifest directly via that hardcoded path. Re-install required if user moves the AI workspace; workspace-init's `repair-workspace` command (v0.2) handles this case.

**No canonical-side marker file in working tree.** Hooks live in `.git/hooks/` which is untracked; doesn't violate "zero AI traces" rule.

### 6.2 Schema v1.0

```json
{
  "schema_version": "1.0",
  "topology": "dual-repo",

  "ai_workspace": {
    "root": "/abs/path/foo-ai",
    "name": "foo-ai",
    "git_tracked": true,
    "git_remote": null
  },
  "canonical": {
    "root": "/abs/path/foo",
    "name": "foo",
    "git_tracked": true,
    "git_remote": null,
    "default_branch": "main"
  },

  "routing": {
    "master_spec":              "ai_workspace",
    "executive_summary":        "canonical",
    "memory_bank":              "ai_workspace",
    "claude_md":                "ai_workspace",
    "agents_md":                "ai_workspace",
    "scaffold_project_outputs": "ai_workspace",
    "backlog":                  "canonical",
    "project_plan":             "canonical",
    "roadmap":                  "canonical",
    "prd":                      "canonical",
    "srs":                      "canonical",
    "product_adrs":             "canonical",
    "process_adrs":             "ai_workspace",
    "sprint_specs":             "ai_workspace",
    "implementation_handoffs":  "ai_workspace",
    "brainstorm_artifacts":     "ai_workspace"
  },

  "during_dev": {
    "worktrees_dir":        "${canonical.root}/.worktrees",
    "branch_naming":        "slice/sprint-{N}-work-{NN}-{kebab-name}",
    "sprint_dir_template":  "${ai_workspace.root}/docs/specs/sprint-{N}",
    "slice_spec_format":    "wabash-format-b-v1"
  },

  "well_known_paths": {
    "master_spec":            "${ai_workspace.root}/docs/MASTER-SPEC.md",
    "memory_bank":            "${ai_workspace.root}/.claude/memory-bank",
    "principles_user_global": "${PLUGIN_DATA:architect-critic}/principles.md",
    "superpowers_brainstorm": "${ai_workspace.root}/.superpowers/brainstorm"
  },

  "git_policy": {
    "project_type": "personal",
    "allow_ai_local_commits": true,
    "allow_ai_local_merge":   true,
    "allow_ai_local_rebase":  true,
    "allow_ai_fetch":         false,
    "allow_ai_push":          false,
    "allow_ai_pull":          false,
    "trace_filter": {
      "enforce": true,
      "blocked_patterns": [
        "^Co-Authored-By:",
        "^🤖 Generated with",
        "<noreply@anthropic\\.com>",
        "<noreply@openai\\.com>"
      ]
    }
  },

  "created_at":      "2026-05-22T14:30:00Z",
  "created_by":      "workspace-init@0.1.0"
}
```

### 6.3 ${var} substitution

Two syntactic forms; both resolved at read-time by `lib/manifest.sh`'s shared `mi_manifest_resolve` helper:

**Form 1 — manifest field reference:** `${ai_workspace.root}`, `${canonical.root}` resolve to values from the manifest itself.

**Form 2 — plugin-data reference:** `${PLUGIN_DATA:<plugin-name>}` resolves to the named plugin's data directory. The resolver looks up the actual path for that plugin (typically `${HOME}/.local/share/claude-code/<plugin-name>/` or whatever Claude Code's plugin-data layout uses).

**Why `${PLUGIN_DATA:<name>}` (not bare `${CLAUDE_PLUGIN_DATA}`):** Claude Code's `CLAUDE_PLUGIN_DATA` env var is set per-process to the INVOKING plugin's data dir. Bare reference produces wrong path when one plugin needs to read another's data. The named form makes the plugin explicit; resolver does the right thing regardless of invoking plugin.

**Standard env-var references** (`${HOME}`, `${USER}`) also supported via standard shell expansion.

### 6.4 Field-level required/optional

| Field | Required? |
|---|---|
| `schema_version`, `topology` | yes |
| `ai_workspace.{root,name,git_tracked}` | yes (`git_remote` may be null) |
| `canonical.{root,name,git_tracked,default_branch}` | yes (`git_remote` may be null) |
| `routing.*` | yes (full set; scaffold-onboard depends on completeness) |
| `during_dev.*` | yes (scaffold-dev uses defaults if values absent at runtime) |
| `well_known_paths.*` | optional (architect-critic falls back to standalone discovery when absent) |
| `git_policy.*` | yes (`trace_filter.blocked_patterns` may be empty) |
| `created_at`, `created_by` | yes |
| `last_updated_at`, `last_updated_by`, `notes` | optional (added on edit by user/migrate tool) |

### 6.5 Versioning policy

- Removal or rename of a v1.0 field is a **breaking change** → bump `schema_version` to `2.0`.
- New optional top-level keys or nested optional fields are **additive** → no bump.
- New routing-table entries are **additive** → no bump.

**Reader/writer split (per adversarial review H4):**
- **workspace-init writes** the current `schema_version` it ships at init/migrate. Doesn't read its own output at runtime.
- **Downstream plugins (scaffold-onboard, scaffold-dev, architect-critic)** READ the manifest on every session start. Each plugin tracks the latest `schema_version` it supports; refuses to read manifests with higher versions, prompting user to update the consumer plugin.

---

## 7. Git policy

### 7.1 project_type prompt

At init: *"Is this a personal project or a work/company project?"* Answer recorded in `git_policy.project_type`. Both project types enforce the trace filter (per Q-B settlement); the distinction is a forward hook for v0.2 differentiation.

### 7.2 Ops allowlist

Per manifest's `git_policy.allow_ai_*` fields. Network ops (push/pull/fetch) default false; in-conversation user override via explicit instruction ("push this", "pull main"). Each plugin reading the manifest respects these.

### 7.3 Trace filter — `commit-msg` git hook

**Enforced patterns (blocked):**
1. Any line matching regex `^Co-Authored-By:` (catches AI AND human co-author trailers; intentional broader catch per user preference)
2. Any line matching regex `^🤖 Generated with` (Claude Code generated marker)
3. Any line containing `<noreply@anthropic.com>` (Anthropic bot email — anchored within angle-brackets to reduce false positives)
4. Any line containing `<noreply@openai.com>` (OpenAI / Codex bot email)

**Hook name: `commit-msg` (not `pre-commit`).** Reason: `commit-msg` is the git hook that receives the path to the temporary commit-message file as `$1`; `pre-commit` receives no args and runs before the message exists. The hook needs the message to filter it. Use `.git/hooks/commit-msg`.

**Implementation: local hook + baked AI workspace path**

```bash
#!/usr/bin/env bash
# workspace-init: commit-msg AI-trace filter (auto-installed)
# DO NOT EDIT — regenerated on workspace-init runs.
# Embedded AI workspace path: /abs/path/foo-ai

AI_WORKSPACE_PATH="/abs/path/foo-ai"    # baked at install time per repo
MANIFEST_PATH="${AI_WORKSPACE_PATH}/.workspace/pairing.json"

commit_msg_file="$1"
if [[ ! -f "$commit_msg_file" ]]; then exit 0; fi

# If manifest missing (AI workspace moved/deleted), fail-open with warning to stderr
if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "warning: workspace-init manifest not found at $MANIFEST_PATH; trace filter disabled. Re-run /init-workspace --repair." >&2
  exit 0
fi

# Trace filter disabled in manifest? exit clean
enforce="$(jq -r '.git_policy.trace_filter.enforce // false' "$MANIFEST_PATH" 2>/dev/null || echo "false")"
if [[ "$enforce" != "true" ]]; then exit 0; fi

# Read patterns; handle empty array gracefully
patterns="$(jq -r '.git_policy.trace_filter.blocked_patterns[]?' "$MANIFEST_PATH" 2>/dev/null || true)"
if [[ -z "$patterns" ]]; then exit 0; fi

# Scan commit message against each pattern
while IFS= read -r pattern; do
  [[ -z "$pattern" ]] && continue
  if grep -qE "$pattern" "$commit_msg_file"; then
    echo "ERROR: commit message contains blocked AI-trace pattern: $pattern" >&2
    echo "       Edit the message and try again, or run with --no-verify to bypass (not recommended)." >&2
    exit 1
  fi
done <<< "$patterns"

exit 0
```

Notes:
- **No `set -e`** — explicit error checks throughout; avoids interaction issues with `grep -q` returning non-zero on no-match
- **Empty patterns array handled** — early-exit if no patterns to check
- **Manifest path baked in** at install time — different per repo; canonical's hook embeds the sibling AI workspace path
- **Fail-open on missing manifest** with stderr warning visible to user
- **Anchored patterns** prevent false positives in commit messages talking about the patterns themselves (e.g., `"docs: document that hook blocks 🤖 Generated with marker"` is fine because the line doesn't START with the marker)

**Installation at workspace-init run time:** the template at `hooks/commit-msg.tmpl` gets rendered (substituting AI workspace path) and copied to `<ai-workspace>/.git/hooks/commit-msg` AND `<canonical>/.git/hooks/commit-msg`. `chmod +x` on both.

**Override:** `git commit --no-verify` bypasses (git's standard escape hatch). Documented in next-steps message.

### 7.4 Workspace-init's own initial commit

workspace-init stages files but does NOT auto-commit. Prints suggested commit message. User runs `git commit -m "..."` themselves. Matches Wabash strict-honor rule.

For canonical in pair-with mode: workspace-init creates no files in canonical's working tree; only modifies `.git/hooks/commit-msg`. Stages nothing in canonical.

---

## 8. Pre-onboard tasks (the 8) + transactional rollback

When workspace-init runs (fresh or pair-with mode), it performs the 8 tasks in order. **All filesystem operations are tracked in `.workspace/init-log` as they happen.** On any failure, rollback walks the log in reverse and undoes operations. Pair-with mode NEVER rolls back operations affecting existing canonical (only the new AI workspace dir gets rolled back).

### 8.1 Task 1: Take user input

Required: project name (kebab-case validation: `[a-z0-9-]+`).
Optional: parent dir (defaults to `cwd`), existing canonical path (for pair-with).

Validation:
- Parent dir exists + writable
- Target dirs absent (fresh mode) OR canonical exists+is-git-repo (pair-with mode)
- Project name passes validation

### 8.2 Task 2: Create the two directories

Fresh mode: `mkdir <parent>/<name>-ai && mkdir <parent>/<name>`. Log both.
Pair-with mode: `mkdir <parent>/<name>-ai`. Log it.

### 8.3 Task 3: Seed AI workspace directory skeleton

Create subdirs: `.workspace/`, `.claude/`, `docs/`, `docs/specs/`, `.superpowers/`, `.archive/`. Each gets a `.gitkeep`. Log each.

Also render `templates/gitignore.tmpl` → `<ai-workspace>/.gitignore`. Minimal v0.1 content:

```
# Onboarding session state (scaffold-onboard)
.claude/.onboarding-state.json

# Handoff escape valve files — per scaffold-dev §6b (durable per-machine; not synced)
.workspace/handoffs/

# OS-level cruft
.DS_Store
*.swp
```

Log .gitignore creation. The `.workspace/handoffs/` entry is required for scaffold-dev's `handing-off-session` skill (per scaffold-dev SPEC §6b.1 — durable per-machine, not committed); without it, handoff files would land in git status and pollute the repo.

### 8.4 Task 4: Write the pairing manifest

Render `<ai-workspace>/.workspace/pairing.json` per §6.2. Log file creation.

For pair-with mode: detect `canonical.git_remote` and `canonical.default_branch` from existing repo. Fallback chain for default branch:

```bash
default_branch="$(git -C "$canonical" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"
[[ -z "$default_branch" ]] && default_branch="$(git -C "$canonical" symbolic-ref HEAD 2>/dev/null | sed 's@^refs/heads/@@')"
[[ -z "$default_branch" ]] && default_branch="$(git -C "$canonical" branch --show-current 2>/dev/null)"
[[ -z "$default_branch" ]] && {
  # Prompt user
  read -r -p "Could not detect default branch for canonical. Enter (e.g., main, master, develop): " default_branch
  [[ -z "$default_branch" ]] && default_branch="main"
}
```

### 8.5 Task 5: Write `CLAUDE.md` stub

`<ai-workspace>/CLAUDE.md` minimal router. Log creation. scaffold-onboard's `/scaffold-project` overwrites later.

### 8.6 Task 6: Write `AGENTS.md` stub

`<ai-workspace>/AGENTS.md` minimal cross-tool agent stub. Log creation.

### 8.7 Task 7: Write `README.md`

`<ai-workspace>/README.md` minimal repo intro. Log creation.

### 8.8 Task 8: Install commit-msg hooks + git init + stage

- `git init` AI workspace (log)
- `git init` canonical (fresh mode only; log)
- Render `hooks/commit-msg.tmpl` with baked AI workspace path → write to AI workspace's `.git/hooks/commit-msg` + `chmod +x` (log)
- Same template, baked path → write to canonical's `.git/hooks/commit-msg` + `chmod +x` (log)
- `git -C <ai-workspace> add .` (stages skeleton)
- Print next-steps message:

```
Workspace bootstrap complete.

  AI workspace:  /abs/path/{name}-ai
  Canonical:     /abs/path/{name}

Both repos initialized + commit-msg trace filter hooks installed.
AI workspace has skeleton + manifest + stubs staged (not yet committed — review + commit yourself).

Next steps:
  1. cd /abs/path/{name}-ai && git status
  2. git commit -m "workspace-init: initial bootstrap (workspace-init v0.1.0)"
  3. cd /abs/path/{name}-ai && claude
  4. /onboard                              # begin scaffold-onboard's 10-phase conversation

Manifest at: /abs/path/{name}-ai/.workspace/pairing.json
Init log at: /abs/path/{name}-ai/.workspace/init-log (rollback record)

To override trace filter for a specific commit: git commit --no-verify
```

### 8.9 Rollback semantics

On ANY task failure mid-init:
1. Read `.workspace/init-log` in reverse order
2. For each op, run its inverse: `mkdir` → `rmdir` (if empty); `git init` → remove `.git/`; file create → `rm`; hook install → remove the hook file
3. Pair-with mode: skip ops affecting existing canonical (their inverse would damage user's existing repo)
4. Emit clear message to user about what was rolled back vs left in place

This converts mid-init failures from "your dirs are now in a broken half-state" to "back to clean slate as if init never ran."

---

## 9. Migration: Scenario A (`--pair-with`)

### 9.1 Scope

v0.1 ships pair-with (Scenario A). **Scenario C** (pair two already-populated repos — `pairing-existing-dual`) added in **v0.2.0** (§9.5, issue #9). Scenario B (split an existing scaffold-onboard'd single-repo into dual) remains deferred.

### 9.2 Invocation

`/pair-workspace /abs/path/to/existing-canonical` or skill trigger.

### 9.3 Behavior

- Existing canonical's WORKING TREE not modified (no files created/changed in working dir)
- Existing canonical's GIT HOOK directory IS modified: `.git/hooks/commit-msg` is installed
- All other existing canonical state (branches, remotes, .gitignore, etc.) unchanged
- New sibling AI workspace created with skeleton + manifest + AGENTS.md + README + CLAUDE.md stub
- Manifest's `canonical.root` points at existing canonical path
- Manifest's `canonical.git_remote` and `canonical.default_branch` detected from existing repo (per §8.4 fallback chain)

### 9.4 Abort conditions

Refuses if existing canonical contains AI scaffolding (`.claude/memory-bank/`, `MASTER-SPEC.md`, `docs/MASTER-SPEC.md`, `.claude/.onboarding-state.json`). Surfaces Scenario B guidance with manual workaround.

### 9.5 Scenario C (`pairing-existing-dual`, v0.2.0)

Both repos already exist and are populated — an AI workspace that grew its memory-bank/specs organically before the plugins were discovered, alongside an existing canonical with production code, with no manifest tying them together yet (issue #9). The `pairing-existing-dual` skill (`/pair-existing-dual <ai-workspace-abs> <canonical-abs>`) writes ONLY the `.workspace/pairing.json` manifest into the existing AI workspace and installs the trace-filter `commit-msg` hook (always in canonical; also in the AI workspace when it is itself a git repo).

- **No abort on AI-scaffolding markers** — unlike §9.4, Scenario C *expects* the AI workspace to contain memory-bank/specs/CLAUDE.md; it detects and surfaces them as "existing state to preserve" rather than aborting.
- **No creation / seeding / stubbing / overwriting** of existing AI-workspace content — the only file authored inside it is `.workspace/pairing.json` (+ the init-log under `.workspace/`).
- **Preflight** (`wi_skeleton_preflight_existing_dual <ai-root> <canonical-root>`): AI workspace exists + non-empty; canonical exists + is a git repo; paths differ. The AI workspace may or may not itself be a git repo (its hook is installed only if it is one).
- **Conservative failure handling** — never a destructive rollback against the populated workspace (the manifest write is atomic; both operations are idempotent and re-runnable).

This is distinct from §9.4's Scenario-B guidance (a single-repo with markers IN the canonical), which remains the deferred split-migration case.

---

## 10. Plugin layout

```
workspace-init/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── initializing-dual-repo-workspace/
│   │   ├── SKILL.md
│   │   └── examples/
│   ├── pairing-canonical-repo/
│   │   ├── SKILL.md
│   │   └── examples/
│   └── pairing-existing-dual/      # Scenario C (§9.5)
│       └── SKILL.md
├── commands/
│   ├── init-workspace.md
│   ├── pair-workspace.md
│   └── pair-existing-dual.md
├── lib/
│   ├── manifest.sh             # write/read/validate; mi_manifest_resolve (${var} + ${PLUGIN_DATA:<name>})
│   ├── trace-filter.sh         # render + install commit-msg hook with baked path
│   ├── git-init.sh             # git init + stage + default-branch detection w/ fallback chain
│   ├── skeleton.sh             # dir creation + .gitkeep + transactional log entry
│   ├── stubs.sh                # render CLAUDE.md/AGENTS.md/README.md from templates
│   ├── rollback.sh             # init-log reader + inverse-op executor
│   └── _helpers.sh             # logging, path canonicalization, jq wrappers
├── hooks/
│   └── commit-msg.tmpl         # template rendered with AI workspace path baked in
├── templates/
│   ├── pairing.json.tmpl
│   ├── CLAUDE.md.stub.tmpl
│   ├── AGENTS.md.stub.tmpl
│   ├── README.md.tmpl
│   └── gitignore.tmpl
├── tests/
│   ├── _helpers.sh
│   ├── test-manifest.sh                # schema validation, ${PLUGIN_DATA:<name>} resolution, ${var} resolution
│   ├── test-trace-filter.sh            # commit-msg hook regex behavior (anchored patterns, empty-array, fail-open)
│   ├── test-skeleton.sh                # dir creation, .gitkeep, idempotency, transactional log
│   ├── test-stubs.sh                   # template rendering
│   ├── test-rollback.sh                # rollback semantics (fresh + pair-with cases)
│   ├── test-default-branch-fallback.sh # git symbolic-ref fallback chain
│   ├── test-init-fresh.sh              # end-to-end fresh bootstrap
│   ├── test-pair-with-existing.sh      # end-to-end pair-with + abort conditions
│   ├── test-pairing-existing-dual.sh   # Scenario C end-to-end (existing populated dual)
│   └── test-skills-pressure.sh         # subagent RED-GREEN scenarios
├── CHANGELOG.md
├── LICENSE
└── README.md
```

**Test count target:** ~105-115 tests (10-15 more than previous estimate to cover new transactional rollback + path-resolver + fallback chain tests).

---

## 11. Integration with peer plugins

### 11.1 scaffold-onboard v0.2 (tight read)

Reads manifest's `routing.*` to decide where each output goes. Uses `mi_manifest_resolve` for paths (handles `${PLUGIN_DATA:<name>}` and `${var}`). Falls back to single-repo behavior when manifest absent.

### 11.2 scaffold-dev v0.1 (tight read)

Reads manifest's repo paths, `during_dev.*`, `well_known_paths.*`, `git_policy.*`. Refuses to start if manifest absent (no degraded mode).

### 11.3 architect-critic v0.2 (loose read)

Optional manifest read for `well_known_paths.master_spec` + `well_known_paths.principles_user_global`. Standalone fallback: `--spec PATH` flag (working in v0.2 per bug fixes) → heuristic discovery (SPEC.md / docs/SPEC.md / restricted to `SPEC*` or `MASTER-SPEC*` filenames; not arbitrary `.md`).

### 11.4 ai-mentor v2.0 (no coupling)

Never reads manifest. Orthogonal. v2.0 shipped 2026-05-24 as scope-cut release (4 skills: grill-me, eli10, fool, council).

---

## 12. Build sequence (Pass D skill-first phases)

### Phase 0 — Evals first (RED)

Dispatch subagents to baseline scenarios: "set up dual-repo workspace for project foo"; "pair AI workspace with existing repo at /path/foo"; "what happens if init fails halfway?". Target: 3+ scenarios per skill.

### Phase 1 — Author SKILL.md bodies

`initializing-dual-repo-workspace/SKILL.md` + `pairing-canonical-repo/SKILL.md`. Each ≥150 lines, ≤500 lines. Address Phase 0 failures.

### Phase 2 — Reference sub-docs

Examples in each skill's `examples/` subdir. One level deep from SKILL.md.

### Phase 3 — Utility scripts (bookkeeping)

Per §10's `lib/` module list. Each handles errors explicitly, no voodoo constants, forward-slash paths only. Includes rollback.sh + manifest.sh resolver.

### Phase 4 — commit-msg hook template

`hooks/commit-msg.tmpl` per §7.3. Test against fixture commit messages (positive matches blocked, negative matches pass, anchored-vs-substring cases).

### Phase 5 — Slash command wrappers

`commands/init-workspace.md` + `commands/pair-workspace.md`. `$ARGUMENTS` bridge.

### Phase 6 — Subagent pressure-test the skills (GREEN-REFACTOR)

Re-run Phase 0 scenarios with skills loaded. Close loopholes.

### Phase 7 — Integration tests

Full bootstrap end-to-end (fresh + pair-with). Verify manifest validates, hook installs in both repos with baked paths, skeleton correct, rollback works on simulated failures.

### Phase 8 — Publish

Bump to v0.1.0. Add to `marketplace.json` at top of chain. Update root README plugin table (5 active + 1 deprecated).

---

## 13. Testing strategy

### 13.1 Test counts target

| Suite | Tests | Coverage |
|---|---|---|
| `test-manifest.sh` | ~25 | schema validation, `${var}` + `${PLUGIN_DATA:<name>}` resolution, missing-field handling, reader/writer version checks |
| `test-trace-filter.sh` | ~20 | anchored patterns (positive + negative cases), empty-array handling, manifest-missing fail-open with warning, --no-verify bypass |
| `test-skeleton.sh` | ~12 | dir creation, .gitkeep, idempotency, init-log entries |
| `test-rollback.sh` | ~10 | fresh-mode rollback, pair-with mode (no canonical damage), partial failure scenarios |
| `test-default-branch-fallback.sh` | ~6 | each step of fallback chain, user-prompt path |
| `test-stubs.sh` | ~10 | template rendering, var substitution |
| `test-init-fresh.sh` | ~15 | full fresh-bootstrap end-to-end |
| `test-pair-with-existing.sh` | ~15 | Scenario A end-to-end + abort conditions |
| `test-pairing-existing-dual.sh` | ~14 | Scenario C (existing populated dual) — preflight, manifest, hooks, content-preservation, non-git AI |
| `test-skills-pressure.sh` | ~10 | subagent RED-GREEN scenarios |
| **Total** | **~123** | |

### 13.2 RED scenarios (Phase 0 baselines)

To be captured during Phase 0. Expected categories:
- Subagent forgets to ask about parent dir; creates dirs in wrong place
- Subagent doesn't validate target dirs absent (clobbers existing)
- Subagent forgets to write manifest or wrong path
- Subagent installs `pre-commit` instead of `commit-msg` (per the original bug)
- Subagent doesn't bake AI workspace path into canonical's hook
- Subagent runs `git commit` instead of staging-only
- Subagent skips hook installs

### 13.3 Edge cases tested explicitly

- Parent dir not writable → fail with clear message
- Project name invalid → fail
- Pair-with path doesn't exist → fail
- Pair-with path not a git repo → fail (or offer to git init)
- Pair-with path has AI scaffolding → abort with Scenario B guidance
- Manifest write fails mid-operation → **rollback** (test that all created paths get cleaned up)
- Hook install fails (symlink, permissions) → rollback prior tasks
- Git symbolic-ref returns nothing → fallback chain to branch --show-current → user prompt
- Empty patterns array in manifest → hook exits clean
- Manifest moves/deleted post-install → canonical hook warns to stderr, fails open
- `${PLUGIN_DATA:<name>}` for nonexistent plugin → resolver returns null with warning

---

## 14. Deferred to v0.2

1. Git remotes auto-setup
2. User-global workspace registry (`~/.config/claude-workspaces/registry.json`)
3. Scenario B migration (split existing scaffold-onboard'd repo)
4. `/repair-workspace` command (re-installs canonical hook if AI workspace moved)
5. `core.hooksPath`-based tracked hook (survives clones)

---

## 15. Open questions

None blocking. Implementation-level questions resolve during PLAN authoring.

---

## 16. Risks

- **R1 — `--no-verify` bypasses trace filter.** Documented as known escape hatch; hook is guardrail, not wall.
- **R2 — Hook doesn't survive clone.** `.git/hooks/` not tracked. v0.2 may switch to `core.hooksPath`.
- **R3 — User moves AI workspace.** Canonical's hook breaks (baked path no longer valid). Hook fails open with stderr warning. Mitigation: `/repair-workspace` command (v0.2) re-installs with new path. v0.1 documents manual workaround: re-run `/init-workspace --repair` or edit the hook file directly.
- **R4 — Scenario A abort conditions might miss edge cases.** Best-effort check; documented limitations.
- **R5 — `${PLUGIN_DATA:<name>}` resolution depends on Claude Code's plugin-data layout.** If Claude Code changes layout, resolver needs update. Mitigation: shared resolver in `lib/manifest.sh` localizes the change.

---

## 17. Iteration log

- **2026-05-17** — Pass A Q1 settled: workspace-init is separate run-once plugin.
- **2026-05-17** — Pass A Q2 settled: classification rules + manifest concept; all 3 edge cases route to canonical.
- **2026-05-17** — Pass A Q3 settled: 5-section manifest schema; `<ai-workspace>/.workspace/pairing.json` path; walk-up discovery from AI workspace; no canonical-side marker.
- **2026-05-17** — Pass D settled: skill-first principle (P1/P2/P3).
- **2026-05-19** — Pass A Q-A settled: 8 pre-onboard tasks (6 required + AGENTS.md + README); git remotes + registry deferred to v0.2.
- **2026-05-19** — Pass A Q-B settled: git init both, stage-don't-commit, minimal `.gitignore`; personal-vs-work prompt; trailer-targeted trace filter enforce-on-both; local pre-commit hook.
- **2026-05-20** — Pass A Q-C settled: Scenario A in v0.1; Scenario B deferred to v0.2.
- **2026-05-20** — SPEC drafted.
- **2026-05-22** — **Adversarial review + grill-me pass.** Major fixes: hook name corrected from `pre-commit` to `commit-msg` (was silently no-op); regex patterns anchored (was blocking own meta-commits); walk-up topology gap resolved via baked AI workspace path in canonical's hook (canonical can't walk-up to sibling); `${PLUGIN_DATA:<plugin-name>}` resolver convention introduced (was wrong cross-plugin resolution); git default-branch fallback chain added; transactional rollback semantics added to §8; schema versioning policy clarified (reader vs writer). Multiple polish items per adversarial report.
- **2026-05-24** — Phase 3 drift-resolution: added `routing.roadmap` (default `"canonical"`) to manifest schema v1.0 §6.2. Needed by scaffold-onboard v0.2's `/plan-roadmap` skill output. Additive change; no schema version bump. Avoids the otherwise-required workspace-init v0.1.1 point release.
- **2026-05-25** — Phase 3 cross-check pass (post all 4 deps shipped: architect-critic v0.2.0, ai-mentor v2.0.0, scaffold-onboard v0.2.0, claude-security-audit v0.1.1):
  - §11.4 ai-mentor version bumped v1.3.0 → v2.0 (stale ref against shipped scope-cut release)
  - §4.3 topology diagram: added `.workspace/handoffs/` line (scaffold-dev §6b uses this dir under workspace-init's `.workspace/` namespace)
  - §8.3 Task 3: extended to render `.gitignore` from `templates/gitignore.tmpl` with explicit content listing including `.workspace/handoffs/` entry (required for scaffold-dev §6b.1 "gitignored" claim to actually hold)
  - Verified clean: marketplace.json (5 plugins inc. claude-security-audit); scaffold-onboard v0.2 composition.invokes; claude-security-audit hook surface (no commit-msg conflict); ai-mentor v2.0 surface (4 skills)

---

## 18. Definition of done (v0.1.0)

- All 8 build phases complete
- ~123 tests passing across 9 suites
- `workspace-init-v0.1.0` tag pushed to origin
- Entry in `.claude-plugin/marketplace.json` at top of chain
- Root README plugin table updated
- scaffold-onboard's existing test-compose.sh STILL PASSES (regression check)
- Installable via `/plugin install workspace-init@claude-agent-scaffolding`
- Subagent pressure tests confirm skill auto-invocation on natural triggers
