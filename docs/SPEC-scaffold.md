# SPEC: scaffold plugin

**Status:** Draft v0.1 — ready for final review before build
**Date:** 2026-04-26
**Owner:** Praveen Kumar Singh
**Repo home:** `claude-agent-scaffolding` marketplace (this repo)
**Companion plugin:** `ai-mentor` (user-level cognitive partner). `scaffold` is the project-level workflow plugin. The two are designed to compose without overlap.
**Target version:** 1.0.0
**Platforms:** Linux, macOS (same as ai-mentor; Windows deferred)

---

## 1. TL;DR

A Claude Code plugin you install once at user level and run on **every project** — fresh or existing. It encodes the four workflow pillars surfaced in the design conversation:

1. **Project init + audit** — bootstrap a new repo with sensible defaults; audit an existing repo for governance gaps.
2. **Slice-driven workflow** — strict 5-phase gates (`spec → contract → scaffold → implement → verify`) with state tracked per branch.
3. **Living governance** — ADR auto-numbering, CHANGELOG entries, runbook templates. Light-touch, kept alive.
4. **Personal-defaults + two-layer CLAUDE.md** — your defaults plus project specifics, regeneratable, materializes correctly into git worktrees so parallel-branch work doesn't go stale.

A bundled **Python MCP server** provides a per-repo memory bank with semantic search (Ollama + `nomic-embed-text`) over four entry types: decisions, patterns, notes, slice retrospectives. All mutable state lives **outside the working tree** at `${CLAUDE_PLUGIN_DATA}/projects/<repo-hash>/`, so worktrees inherit (or fork) state correctly and never silently diverge.

---

## 2. Motivation

Three concrete workflow pains observed in the user's daily work:

**P1 — Worktree state divergence.** When you `git worktree add` a parallel branch to try an alternate approach, all gitignored agent files (CLAUDE.md, slice plans, agent state) don't carry over. Each worktree starts cold; merging insights between parallel approaches is manual.

**P2 — Slice ceremony is high-friction when manual.** Slice-driven dev is the user's preferred methodology (visible in the `~/.claude/plans/` dir: `slice-NN-*-spec.md` files, sprint kickoffs, slice retrospectives). Each slice currently requires hand-rolled ceremony: write spec, write tests, scaffold, implement, verify. Easy to skip steps under pressure — and the cost (drift, regression, lost context) shows up later.

**P3 — Governance drift is silent.** ADRs don't get written; CHANGELOG falls behind; runbooks don't exist until an incident at 3am. The "right time" to write each is during the work, not later — but only if it's a single slash command away.

This plugin makes the user's existing workflow mechanical, queryable, and worktree-safe.

---

## 3. Goals & non-goals

### Goals
- **G1.** Run on EVERY project (fresh or existing) — minimal entry friction.
- **G2.** Encode the user's slice-driven methodology with mechanical phase gates.
- **G3.** Provide a queryable memory bank that survives across sessions and worktrees.
- **G4.** Make worktree forking trivial — state inherits cleanly; memory is shared per-repo.
- **G5.** Light governance commands — ADR/CHANGELOG/runbook should each take ≤ 30 seconds.
- **G6.** Compose with `ai-mentor` without command collisions or behavioral overlap.

### Non-goals
- **NG1.** Heavy SDLC artifact templates (full SRS, full PRD, complete STRIDE matrix). The v1 archived spec covered these via greenfield-architect; not in this plugin.
- **NG2.** Cross-machine state synchronization. Relies on user's existing sync of `${CLAUDE_PLUGIN_DATA}` if any.
- **NG3.** Team coordination — personal scaffolding only. Multi-user features deferred.
- **NG4.** CI/CD integration. Slice phase gates are local-only.
- **NG5.** Cognitive-mode enforcement (Curve 1 vs Curve 2). That is `ai-mentor`'s responsibility; this plugin defers to it.
- **NG6.** Test framework abstraction or test-runner functionality. Slice-contract phase detects existing test setup; doesn't install one.

---

## 4. Architecture overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              scaffold plugin                             │
│                  user-level install · per-project state                  │
│                                                                          │
│  ┌─────────────────────┐   ┌──────────────────────────────────────────┐  │
│  │  Capability 1       │   │  Capability 2                            │  │
│  │  Project init/audit │   │  Slice workflow (strict 5-phase gates)   │  │
│  │  /scaffold-init     │   │  spec → contract → scaffold              │  │
│  │  /scaffold-audit    │   │       → implement → verify               │  │
│  │  /scaffold-status   │   │  state per (repo, branch)                │  │
│  └─────────────────────┘   └──────────────────────────────────────────┘  │
│                                                                          │
│  ┌─────────────────────┐   ┌──────────────────────────────────────────┐  │
│  │  Capability 3       │   │  Capability 4                            │  │
│  │  Living governance  │   │  Personal defaults + 2-layer CLAUDE.md   │  │
│  │  /adr-new           │   │  /scaffold-claude-md-edit                │  │
│  │  /changelog         │   │  /scaffold-claude-md-rebuild             │  │
│  │  /runbook-new       │   │  /scaffold-worktree-fork  (materializes) │  │
│  └─────────────────────┘   └──────────────────────────────────────────┘  │
│                                                                          │
│                         ┌──────────────────────┐                         │
│                         │  Memory Bank         │  (MCP server, Python)   │
│                         │  decisions / patterns│  Ollama embeddings      │
│                         │  notes / retrospects │  semantic + FTS5        │
│                         └──────────────────────┘                         │
└──────────────────────────────────────────────────────────────────────────┘

State partition:
  ${CLAUDE_PLUGIN_DATA}/                       (user-global, plugin-update-safe)
  └── projects/<repo-hash>/
      ├── memory.db                            (SQLite + sqlite-vec; per-repo)
      ├── personal-defaults.md ← (symlink)→ ../../personal-defaults.md
      ├── claude-md-project.md                 (per-repo CLAUDE.md additions)
      └── branches/<branch-name>/
          └── state.json                       (current slice, phase, audit log)

  ${CLAUDE_PLUGIN_DATA}/personal-defaults.md   (one file across all projects)

  <repo>/                                      (working tree)
  ├── CLAUDE.md                                (generated; gitignored as user's preference)
  ├── docs/adr/NNNN-*.md                       (committed)
  ├── docs/runbooks/*.md                       (committed)
  ├── docs/slices/slice-NN-*.md                (committed)
  ├── CHANGELOG.md                             (committed)
  └── .claude/scaffold/                        (gitignored — user's global gitignore)
      └── (intentionally empty; state lives in plugin data, not the repo)
```

The `.claude/scaffold/` dir in the repo is a passive marker (intentionally empty); the **canonical signal that a repo is scaffold-managed is the presence of `${CLAUDE_PLUGIN_DATA}/projects/<repo-hash>/` with a non-empty state.json for the current branch**. The marker dir is gitignored (per the user's global `.gitignore` rules) and therefore does not survive `git worktree add` — relying on plugin-data presence makes worktree detection automatic via the deterministic repo-hash.

---

## 5. Detailed design

### 5.1 Capability 1 — Project init + audit

**`/scaffold-init`** — runs in any working directory. Detects whether it's a fresh repo, existing untouched-by-scaffold repo, or already scaffold-managed.

| Detected state | Behavior |
|---|---|
| Fresh empty dir or `git init`'d but no files | Bootstrap: write LICENSE (asks user for license type), `.gitignore` (lang-aware via stack detection), `README.md` skeleton, `CLAUDE.md` (generated from personal-defaults + project layer), `docs/` skeleton with `adr/` `runbooks/` `slices/` subdirs, marker dir `.claude/scaffold/`. Initialize state at `${CLAUDE_PLUGIN_DATA}/projects/<repo-hash>/branches/<current-branch>/state.json`. |
| Existing repo, scaffold-unmanaged (no marker dir, no plugin-data entry) | Onboarding flow: detect language/stack, offer to add missing pieces (CLAUDE.md, docs structure, marker dir). Never overwrite existing files; only add. |
| Already scaffold-managed | No-op with status output. Suggest `/scaffold-status` or `/scaffold-audit`. |

**Branch detection.** Use `git rev-parse --abbrev-ref HEAD`. If output is `HEAD` (detached state), fall back to `_detached_<short-sha>` so each detached state still gets isolated state. If repo has no commits yet (fresh `git init`), use `_unborn`. Branch name is sanitized (replace `/` with `__`) when used as a directory name in plugin data.

**Stack detection** (used by init for `.gitignore` and CLAUDE.md project-layer seeding):
- Python: `pyproject.toml`, `requirements.txt`, `setup.py` → uses Python `.gitignore` template
- JS/TS: `package.json`, `tsconfig.json` → Node template
- Rust: `Cargo.toml` → Rust template
- Go: `go.mod` → Go template
- Multi-stack repos: union of templates
- Unknown: minimal generic `.gitignore`

**LLM-project detection** (signals → enables LLM-specific CLAUDE.md hints, audit items):
- `pyproject.toml`/`requirements.txt`: `openai`, `anthropic`, `langchain`, `langgraph`, `llama-index`, `transformers`, `mcp`, `instructor`, `outlines`, `dspy`
- `package.json`: `@anthropic-ai/sdk`, `openai`, `langchain`, `ai`, `@ai-sdk/*`
- Filesystem: `agents/`, `prompts/`, `evals/`, `tools/` at repo or `src/` root
- `.env*`: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`

If any signal matches → LLM project flag in state → audit checks for `evals/` dir, model-card mentions in README, prompt-governance notes.

**`/scaffold-audit`** — gap analysis on an existing repo. Outputs a markdown table to terminal (and optionally to `docs/AUDIT.md` with a flag).

Audit categories and checks:

| Category | Check | Pass criterion |
|---|---|---|
| README | Has README.md | File exists |
| README | README has Quickstart section | `## Quickstart` heading exists |
| License | LICENSE file | Exists with recognized SPDX content |
| Gitignore | .gitignore exists | Exists |
| Gitignore | Language-appropriate entries | Stack-detected entries present |
| ADRs | `docs/adr/` directory | Exists |
| ADRs | At least one ADR | ≥ 1 file matching `NNNN-*.md` |
| Runbooks | `docs/runbooks/` | Optional; flag missing as Info, not Warning |
| Slices | `docs/slices/` | Optional |
| Tests | Test framework detected | One of pytest/vitest/jest/cargo-test/go-test detected |
| Tests | Tests exist | At least one test file detected |
| LLM-only: evals | `evals/` directory | Exists if LLM project |
| LLM-only: model card | Model name documented | README or docs/MODEL_CARD.md mentions a model |

Output rows: `✓ pass`, `⚠ warning`, `Ⅰ info`, `✗ fail`. Exit code: 0 if no `fail` rows; 1 otherwise (so it can be wired into pre-commit later if user wants).

**`/scaffold-status`** — show current state file contents in a human-readable form: detected stack, LLM flag, current slice, current slice phase, last audit timestamp, branch, worktree count.

### 5.2 Capability 2 — Slice workflow with strict phase gates

**Five phases**, sequenced strictly. Each phase has a gate (prerequisites that must hold before entry) and emits artifacts that the next phase's gate checks for.

```
                ┌─────┐    ┌──────────┐    ┌──────────┐    ┌───────────┐    ┌────────┐
   /slice-new ─→│spec │ ─→ │ contract │ ─→ │ scaffold │ ─→ │ implement │ ─→ │ verify │ ─→ done
                └─────┘    └──────────┘    └──────────┘    └───────────┘    └────────┘
                  ↑          ↑              ↑               ↑                ↑
            /slice-spec  /slice-contract /slice-scaffold  /slice-implement  /slice-verify
```

**Phase contract** (gate → artifact):

| Phase | Prerequisites (gate) | Phase emits | Next phase needs |
|---|---|---|---|
| `spec` | None — entered fresh via `/slice-new <name>` | `docs/slices/slice-NN-<name>.md` populated from template, with acceptance criteria as a checklist. State `phase=spec`, `slice_path` set. | A spec file exists with at least one acceptance criterion. |
| `contract` | `spec_path` exists, ≥ 1 acceptance criterion in spec | `tests/...` files containing failing tests for each acceptance criterion. State `phase=contract`, `test_paths` set. | Test framework detected; ≥ 1 of `test_paths` runs and fails. |
| `scaffold` | All `test_paths` exist; at least one fails (verified by running the test command) | New code files (skeletons, types, glue) written but tests still failing because logic is missing. State `phase=scaffold`, `scaffold_files` set. | All scaffold files exist; tests still failing. |
| `implement` | `scaffold_files` exist, tests still failing | Implementation logic added; tests start passing one by one. State `phase=implement`, no gate on # passing — user iterates. | Some tests passing; user runs `/slice-verify` when ready. |
| `verify` | At least one acceptance-criterion-mapped test passes | Run all `test_paths`; report which acceptance criteria pass/fail; mark slice `complete` if all pass. State `phase=complete` or `phase=verify` if some failing. | — |

**Gate enforcement.** Phase commands refuse to advance state if prerequisites unmet. Error format:

> `/slice-implement` cannot run yet. The contract phase requires at least one failing test. Detected: `tests/test_auth.py` exists but `pytest tests/test_auth.py` returned 0 (all passing). Either add a failing test for the next acceptance criterion via `/slice-contract`, or run `/slice-verify` to mark the slice complete.

**Override:** `/slice-reset` clears phase state for a slice (does not delete files), allowing re-entry from any phase. Used when reality diverges from the gate (e.g., slice scope changed mid-flight).

**Test framework detection** (used by contract+verify phases):

| Stack signal | Test command |
|---|---|
| `pytest.ini` / `pyproject.toml [tool.pytest]` / `tests/conftest.py` | `pytest tests/` |
| `vitest.config.{js,ts}` | `vitest run` |
| `jest.config.{js,ts}` / `package.json` jest key | `jest` |
| `Cargo.toml` | `cargo test` |
| `go.mod` | `go test ./...` |
| Unknown | refuse contract phase; ask user to specify framework |

**Slice state schema** (per-branch, in `${CLAUDE_PLUGIN_DATA}/projects/<repo-hash>/branches/<branch>/state.json`):

```json
{
  "schema_version": 1,
  "current_slice": "slice-04-auth-rewrite",
  "slices": {
    "slice-04-auth-rewrite": {
      "name": "auth-rewrite",
      "number": 4,
      "phase": "implement",
      "spec_path": "docs/slices/slice-04-auth-rewrite.md",
      "test_paths": ["tests/test_auth.py"],
      "scaffold_files": ["src/auth/__init__.py", "src/auth/oauth.py"],
      "acceptance_criteria": [
        { "id": "AC-1", "text": "User can log in with Google", "status": "passing" },
        { "id": "AC-2", "text": "Session persists 24h", "status": "failing" },
        { "id": "AC-3", "text": "Logout clears session", "status": "pending" }
      ],
      "created_at": "2026-04-26T10:00:00Z",
      "updated_at": "2026-04-26T11:30:00Z",
      "test_command": "pytest tests/test_auth.py"
    },
    "slice-03-real-adapters": { /* … */ "phase": "complete" }
  },
  "stack": ["python"],
  "llm_project": false,
  "last_audit_at": "2026-04-26T09:00:00Z",
  "audit_results_path": null
}
```

### 5.3 Capability 3 — Living governance

**`/adr-new`** — interactive: prompts for title, context, options, decision, consequences. Writes `docs/adr/NNNN-<slug>.md` where `NNNN` is the next number. Increments `adr_counter` in state. Format: Michael Nygard ADR template.

**`/changelog [bump]`** — appends an entry to `CHANGELOG.md` (creates if missing) following Keep-a-Changelog 1.1.0 format. Without args: prompts for change type (Added/Changed/Fixed/Removed/Security) and summary. With `bump`: prompts for version (or detects from `package.json`/`pyproject.toml`) and rotates Unreleased to a versioned entry.

**`/runbook-new`** — interactive: prompts for failure-mode name (e.g., "high-latency-writes"), symptoms, diagnosis steps, remediation steps, links to dashboards. Writes `docs/runbooks/<slug>.md` from template.

**Deferred to v1.1** (flagged here so we don't forget):
- `/spec-drift` — compare current `docs/slices/slice-NN-*.md` acceptance criteria against test-suite results. Flag drift. Requires non-trivial parsing; hold for v1.1.

### 5.4 Capability 4 — Personal defaults + two-layer CLAUDE.md

**Two source files concatenate to produce `<repo>/CLAUDE.md`:**

| Source | Path | Scope | Edit via |
|---|---|---|---|
| Personal-defaults layer | `${CLAUDE_PLUGIN_DATA}/personal-defaults.md` | User-global; same on every project | `/scaffold-claude-md-edit personal` |
| Project layer | `${CLAUDE_PLUGIN_DATA}/projects/<repo-hash>/claude-md-project.md` | Per-repo; tech stack, conventions, project gotchas | `/scaffold-claude-md-edit project` |

**Generated output:** `<repo>/CLAUDE.md` with two sections:

```markdown
# Personal preferences (synced from ${CLAUDE_PLUGIN_DATA}/personal-defaults.md)

<contents of personal-defaults.md>

---

# Project: <repo-name>

<contents of claude-md-project.md>

---

<!-- Generated by scaffold v1.0.0 at <timestamp>. Do not edit directly. Edit the source layers via /scaffold-claude-md-edit. -->
```

**Generation triggers:**
- `/scaffold-init` (fresh project): seeds project layer from a template, generates CLAUDE.md
- `/scaffold-claude-md-edit personal|project`: opens the source layer in `$EDITOR`; on save, regenerates CLAUDE.md
- `/scaffold-claude-md-rebuild`: explicit regenerate (use when sources changed externally, or after personal-defaults sync from another machine)
- `/scaffold-worktree-fork <branch>`: regenerates inside the new worktree (so each worktree has its own CLAUDE.md file even though sources are shared)

**First-edit experience:** if `personal-defaults.md` doesn't exist on first plugin use, scaffold seeds it from a template (an opinionated default with concise/terse-mode preferences) and opens it in `$EDITOR`. User can fully replace.

**Existing CLAUDE.md handling.** If `<repo>/CLAUDE.md` already exists when `/scaffold-init` runs (user wrote it manually before installing scaffold), do NOT overwrite. Three options offered interactively:
1. **Import** — copy the existing file's content into `claude-md-project.md` as the project layer. Then regenerate `<repo>/CLAUDE.md` (now it'll have personal-defaults prepended). User reviews the merge.
2. **Keep as-is** — skip CLAUDE.md generation entirely for this repo. State records `claude_md_managed=false` so subsequent generation triggers no-op. User can opt back in later via `/scaffold-claude-md-rebuild --take-over`.
3. **Replace** — back up to `CLAUDE.md.backup` and proceed with normal generation.

Default selection on prompt: import. Most users have project-specific content worth preserving.

**Manual edit detection:** `<repo>/CLAUDE.md` has a footer comment with the generation timestamp. If the file is edited manually (timestamp out of sync with mtime), `/scaffold-claude-md-rebuild` warns: "Detected manual edits since last generation. Saving them back via `/scaffold-claude-md-save` (v1.1) or overwrite?"

**Personal-defaults seed template** (initial content, user-replaceable):

```markdown
## Communication preferences
- Concise responses. No trailing summaries; the diff is the summary.
- Code blocks without surrounding narration unless context matters.
- Ask before creating files beyond what's asked.

## Code preferences
- Functions under ~50 lines.
- Comments only for non-obvious WHY, never for WHAT.
- Pathlib over os.path in Python; StrEnum for fixed sets; Exceptions over Optional[T] for error paths.

## Testing preferences
- Tests first for deterministic layers; tests-after for LLM-dependent layers.
- Real databases over mocks for integration tests.

## Collaboration
- Mark risky actions (destructive git, rm -rf, pushes) and confirm before executing.
- Use Plan skill for non-trivial changes before implementation.
```

### 5.5 Memory bank — Python MCP server

**Backend:** SQLite + `sqlite-vec` extension for vector search, with FTS5 fallback for keyword. Embeddings via Ollama (`nomic-embed-text:latest`, 768-dim). Storage path: `${CLAUDE_PLUGIN_DATA}/projects/<repo-hash>/memory.db`.

**Schema:**

```sql
CREATE TABLE memory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL CHECK(type IN ('decision', 'pattern', 'note', 'retrospective')),
  title TEXT,
  body TEXT NOT NULL,
  tags TEXT,                  -- JSON array
  branch TEXT,                -- branch active when recorded; NULL if cross-branch
  related_files TEXT,         -- JSON array
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE VIRTUAL TABLE memory_fts USING fts5(
  title, body, tags,
  content='memory', content_rowid='id'
);

CREATE VIRTUAL TABLE memory_vec USING vec0(
  embedding float[768]
);

-- triggers keep memory_fts and memory_vec in sync with memory
```

**MCP tools (9):**

| Tool | Purpose |
|---|---|
| `record_decision(title, context, options, decision, rationale, tags?)` | Create decision entry. Auto-embeds. |
| `record_pattern(name, description, example_files?, tags?)` | Create pattern entry. |
| `record_note(text, tags?)` | Free-form note with tags. |
| `record_retrospective(slice_name, what_worked, what_didnt, learnings)` | Slice retrospective. |
| `recall(query, type?, limit=5, min_score=0.3)` | Hybrid retrieval — vector search + FTS5, ranked by combined score. Filters by type if given. |
| `list_recent(type?, limit=10, since?)` | Chronological recent items. |
| `get_by_id(id)` | Direct lookup. |
| `update(id, fields)` | Edit existing entry; re-embeds if body changes. |
| `delete(id)` | Remove entry. |

**Hybrid retrieval algorithm** (for `recall`):
1. Embed query via Ollama (`POST /api/embeddings`).
2. Vector search top 20 by cosine similarity in `memory_vec`.
3. FTS5 search top 20 by BM25 in `memory_fts`.
4. Merge: union, scored by `0.6 * vec_sim + 0.4 * normalized_bm25`.
5. Filter by `type` if provided.
6. Return top `limit` with `{id, type, title, body_excerpt, score, created_at}`.

**Fallback when Ollama not running:** detected at startup (one-time `GET /api/tags` ping). If unavailable, `record_*` tools store entries without embeddings (NULL in `memory_vec`) and `recall` falls back to FTS5-only. Plugin emits a one-time warning: "Ollama not running; semantic search disabled, keyword search active. Run `ollama serve` and `/scaffold-memory-reindex` to enable."

**Reindex command** (`/scaffold-memory-reindex`): walks all entries with NULL embeddings, computes them, populates `memory_vec`. Useful after first running Ollama on entries created earlier.

**Recall scope.** Memory is per-repo (`memory.db` lives at `${CLAUDE_PLUGIN_DATA}/projects/<repo-hash>/`). All MCP tools operate within the current repo only — no cross-repo retrieval in v1. Cross-repo recall is reasonable v1.x feature once the per-repo experience is solid (would require choosing between "all repos" or "named repos" scoping; defer until requested).

**MCP server lifecycle.** Claude Code starts the MCP server lazily — on first invocation of any `scaffold-memory` tool — and keeps it running for the session. The server connects to `memory.db` for the current repo (resolved via `git rev-parse --show-toplevel` + repo-hash). When session ends, server exits. No daemon.

**MCP server registration in plugin.json:**

```json
{
  "mcpServers": {
    "scaffold-memory": {
      "command": "${CLAUDE_PLUGIN_ROOT}/mcp/run-server.sh",
      "args": [],
      "env": {
        "SCAFFOLD_DATA_DIR": "${CLAUDE_PLUGIN_DATA}",
        "OLLAMA_HOST": "http://localhost:11434"
      }
    }
  }
}
```

`run-server.sh` activates the plugin's bundled venv and runs `python -m scaffold_memory.server`. Setup script (`scripts/install.sh`) creates the venv on first install.

### 5.6 Worktree forking

**`/scaffold-worktree-fork <new-branch>`** — does three things in sequence:

1. **Create the worktree.** Wraps `git worktree add ../<repo>-<branch> -b <new-branch>` (or accepts a custom path via `--path`). Errors if the branch already exists or the path is occupied.
2. **Fork branch state.** Read parent branch's state file at `${CLAUDE_PLUGIN_DATA}/projects/<repo-hash>/branches/<parent>/state.json`. Copy to `branches/<new-branch>/state.json` with `current_slice` reset (forking starts a fresh slice context, doesn't inherit mid-slice state). Memory bank is shared per-repo, no copy needed.
3. **Materialize CLAUDE.md.** In the new worktree, generate `<new-worktree>/CLAUDE.md` from the same source layers (personal + project). Identical content across all worktrees of the same repo.

**`/scaffold-worktree-list`** — prints all worktrees of the current repo with: path, branch, current slice, slice phase, last activity timestamp.

**Memory bank scoping in worktrees:** the MCP server is started by Claude Code per-session. Each worktree session connects to the same `memory.db` (per-repo path). Decisions/patterns/notes recorded in worktree A are visible in worktree B's recall. Slice retrospectives include the `branch` field so cross-branch retrieval can filter by branch when meaningful.

---

## 6. State partitioning summary

Three storage layers, each chosen deliberately:

| Layer | Path | Lifetime | Worktree behavior |
|---|---|---|---|
| **Plugin code (immutable)** | `${CLAUDE_PLUGIN_ROOT}/` | Survives plugin updates as a snapshot; ROOT changes on update | Same on all worktrees (read from plugin install dir, not the working tree) |
| **Plugin data (mutable, persistent)** | `${CLAUDE_PLUGIN_DATA}/` | Survives plugin updates | Shared across worktrees of the same repo (memory.db) and forked across branches (state.json) |
| **Working tree (committed)** | `<repo>/` | Per-branch git history | Different per branch by design (specs, ADRs, runbooks committed; CLAUDE.md generated per-worktree) |

**Nothing mutable lives in the working tree** except generated artifacts (CLAUDE.md). All slice progress, audit history, memory entries live in plugin data.

---

## 7. Slash command catalog (18 commands in v1)

| Command | Args | Purpose |
|---|---|---|
| **Init/audit (3)** | | |
| `/scaffold-init` | none | Bootstrap or onboard current repo |
| `/scaffold-audit` | `[--save]` | Gap analysis; optionally writes `docs/AUDIT.md` |
| `/scaffold-status` | none | Show current state (slice, phase, stack, etc.) |
| **CLAUDE.md (2)** | | |
| `/scaffold-claude-md-edit` | `personal\|project` | Open source layer in $EDITOR; regenerate on save |
| `/scaffold-claude-md-rebuild` | none | Regenerate `<repo>/CLAUDE.md` from current source layers |
| **Worktree (2)** | | |
| `/scaffold-worktree-fork` | `<branch> [--path <p>]` | Create worktree + fork state + materialize CLAUDE.md |
| `/scaffold-worktree-list` | none | List worktrees with branch + slice progress |
| **Slice (8)** | | |
| `/slice-new` | `<name>` | Start a new slice; create spec file from template; phase=spec |
| `/slice-status` | none | Show current slice phase, AC checklist, test status |
| `/slice-list` | none | List all slices on current branch with phase + status |
| `/slice-spec` | none | Re-enter spec phase (interactive AC capture) |
| `/slice-contract` | none | Enter contract phase: scaffold failing tests for each AC |
| `/slice-scaffold` | none | Enter scaffold phase: write skeletons (Zone 1 with ai-mentor) |
| `/slice-implement` | none | Enter implement phase; gate-checked |
| `/slice-verify` | none | Run tests; report AC pass/fail; mark complete if all pass |
| **Governance (3)** | | |
| `/adr-new` | none | Interactive ADR; auto-numbers; writes `docs/adr/NNNN-*.md` |
| `/changelog` | `[bump]` | Append CHANGELOG entry (or rotate Unreleased to versioned) |
| `/runbook-new` | none | Interactive runbook; writes `docs/runbooks/*.md` |

**Memory bank tools** are MCP tools (not slash commands) — invoked by Claude when contextually relevant. The user can also invoke them directly via natural language ("record a decision: …", "recall any decisions about caching").

**Total v1 command count: 18 slash commands + 9 MCP tools.**

Deferred to v1.1+:
- `/slice-reset` (override stuck phase) — easy add
- `/scaffold-memory-reindex` (rebuild embeddings after Ollama install) — easy add
- `/spec-drift` (spec ↔ code drift detection) — non-trivial, needs design
- `/scaffold-claude-md-save` (push manual CLAUDE.md edits back to source) — needs conflict logic

---

**SessionStart source-awareness.** Mirrors ai-mentor v1.1's pattern. Hook reads the `source` field:

| `source` | Behavior |
|---|---|
| `startup` | Detect scaffold-managed (via plugin-data presence); inject project context if managed |
| `clear` | Same as startup |
| `resume` | Detect + inject (preserves continuity in long sessions) |
| `compact` | Detect + inject (resilience against context compaction — user's slice/phase awareness survives) |

Unlike ai-mentor, scaffold has no mutable per-session state to reset (slice state lives in branch state.json, not session state). So the source-aware behavior here is purely about "do we re-emit the project context or not." Always re-emit; the cost is small (~200-300 tokens) and the benefit is the agent staying aware of current slice + phase through compaction.

## 8. Plugin layout

```
scaffold/
├── .claude-plugin/plugin.json                  # name, version, mcpServers config
├── hooks/hooks.json                            # SessionStart only (source-aware)
├── hooks-handlers/
│   └── session-start.sh                        # detect scaffold-managed repo via plugin-data;
│                                               # inject project context (slice, phase,
│                                               # llm_project flag, recent decisions);
│                                               # ~200-300 tokens; only when managed
│                                               # source-aware (re-emit on compact/resume)
├── lib/
│   ├── state.sh                                # state.json read/write helpers
│   ├── repo.sh                                 # repo-hash, branch detection,
│   │                                           # stack detection, LLM detection
│   ├── claude-md.sh                            # CLAUDE.md generator
│   ├── slice.sh                                # phase gate logic, test detection
│   └── audit.sh                                # audit checks
├── mcp/
│   ├── run-server.sh                           # activates venv, launches server
│   ├── server.py                               # FastMCP server entry
│   ├── memory/
│   │   ├── __init__.py
│   │   ├── db.py                               # sqlite + sqlite-vec setup
│   │   ├── embed.py                            # Ollama wrapper + fallback detect
│   │   ├── search.py                           # hybrid retrieval algorithm
│   │   └── tools/
│   │       ├── record_decision.py
│   │       ├── record_pattern.py
│   │       ├── record_note.py
│   │       ├── record_retrospective.py
│   │       ├── recall.py
│   │       ├── list_recent.py
│   │       ├── get_by_id.py
│   │       ├── update.py
│   │       └── delete.py
│   └── requirements.txt                        # fastmcp, sqlite-vec, requests, pydantic
├── skills/
│   └── scaffold/SKILL.md                       # detailed reference (loaded on demand)
├── commands/
│   ├── scaffold-init.md
│   ├── scaffold-audit.md
│   ├── scaffold-status.md
│   ├── scaffold-claude-md-edit.md
│   ├── scaffold-claude-md-rebuild.md
│   ├── scaffold-worktree-fork.md
│   ├── scaffold-worktree-list.md
│   ├── slice-new.md
│   ├── slice-status.md
│   ├── slice-list.md
│   ├── slice-spec.md
│   ├── slice-contract.md
│   ├── slice-scaffold.md
│   ├── slice-implement.md
│   ├── slice-verify.md
│   ├── adr-new.md
│   ├── changelog.md
│   └── runbook-new.md
├── templates/
│   ├── claude-md-personal-defaults.md          # seed for personal layer
│   ├── claude-md-project.md.tmpl               # seed for project layer
│   ├── slice-spec.md.tmpl                      # slice spec template
│   ├── adr.md.tmpl                             # Nygard ADR template
│   ├── runbook.md.tmpl                         # SRE-style runbook template
│   ├── changelog.md.tmpl                       # Keep-a-Changelog seed
│   ├── readme.md.tmpl                          # README skeleton
│   └── gitignore/                              # per-language gitignore templates
│       ├── python.gitignore
│       ├── node.gitignore
│       ├── rust.gitignore
│       └── go.gitignore
├── scripts/
│   ├── install.sh                              # one-time: create plugin venv,
│   │                                           # install requirements.txt,
│   │                                           # check for Ollama (warn if missing)
│   └── reindex.sh                              # rebuild embeddings (manual run)
├── tests/
│   ├── test-state.sh                           # state file helpers
│   ├── test-claude-md.sh                       # CLAUDE.md generator
│   ├── test-slice-gates.sh                     # phase gate logic
│   ├── test-audit.sh                           # audit checks
│   └── test-mcp.sh                             # MCP tools (subprocess + JSON-RPC)
├── README.md
├── CHANGELOG.md
└── LICENSE
```

---

## 9. Workflows / use cases

**Use case A — fresh project bootstrap.**
```
$ cd ~/projects/new-thing && git init
$ # in Claude Code:
> /scaffold-init
[scaffold] Detected: empty git repo. Stack: undetected (no signals).
[scaffold] Asking: license? (MIT/Apache-2.0/BSD-3/none) → MIT
[scaffold] Generated: LICENSE, .gitignore (minimal), README.md, CLAUDE.md, docs/{adr,runbooks,slices}/
[scaffold] State initialized at ${CLAUDE_PLUGIN_DATA}/projects/abc123/branches/main/state.json
> /slice-new walking-skeleton
[scaffold] Slice 1: walking-skeleton. Phase: spec. Wrote docs/slices/slice-01-walking-skeleton.md.
> /slice-spec
(interactive: AC capture)
> /slice-contract
(scaffolds tests/test_walking_skeleton.py with failing assertions for each AC)
> /slice-scaffold
(writes src/main.py skeleton; tests still fail)
> /slice-implement
(user types code OR ai-mentor allows AI to type if /z1)
> /slice-verify
[scaffold] All 3 acceptance criteria pass. Slice 1 complete.
```

**Use case B — parallel worktrees for two approaches.**
```
> /slice-new auth-rewrite
> # work through phases on slice up to /slice-scaffold
> /scaffold-worktree-fork auth-rewrite-alt
[scaffold] Created worktree at ../new-thing-auth-rewrite-alt on branch auth-rewrite-alt.
[scaffold] Forked state from branch auth-rewrite. Current slice reset; specs/tests inherited via git.
[scaffold] Generated CLAUDE.md inside new worktree.
$ cd ../new-thing-auth-rewrite-alt
> # try alternate approach
> /slice-new auth-rewrite-alt-spike
> # both worktrees share memory.db; decisions in either are visible to the other
```

**Use case C — recall on a long-running project.**
```
> "Did we ever decide anything about caching strategy?"
[Claude calls MCP tool recall(query="caching strategy", type="decision")]
[Returns 3 hits. Top: "Cache aside vs. write-through" decision from 2026-03-15, recorded by /scaffold-init in slice-08.]
[Claude summarizes the decision and rationale, links to the slice spec.]
```

**Use case D — composition with ai-mentor.**
```
> /z2-decide
[ai-mentor: zone=2/decide]
> /slice-new auth-flow
[scaffold: slice 5 created in spec phase]
> /slice-spec
[ai-mentor blocks Edit because /scaffold-init wants to write the slice file in z2/decide]
> # User realizes they want decision-mode, not blocked from authoring spec.
> # Resolution: user runs /z1 (spec authoring is Curve 1 — mechanical, template-driven)
> /z1
> /slice-spec  # now spec file gets written
> # When acceptance criteria need real architectural thought:
> /z2-decide
> # User and AI work through ACs Socratically.
> /locked  # decisions locked
> /slice-contract  # tests get scaffolded by AI
```

This composition pattern is documented in scaffold's SKILL.md: spec-authoring and scaffold operations are Curve 1; decision-rich AC capture and architectural thinking are where you flip to z2-decide.

---

## 10. Composition with ai-mentor

The two plugins must compose without overlap or conflict. Verified disjoint surfaces:

| Surface | ai-mentor | scaffold |
|---|---|---|
| Slash commands | `/z1`, `/z2-decide`, `/z2-build`, `/locked`, `/quiz`, `/eli10`, `/fool` | 18 commands listed in §7. **No overlap.** |
| State location | `${CLAUDE_PLUGIN_DATA}/state.json` (within `ai-mentor-claude-agent-scaffolding`) | `${CLAUDE_PLUGIN_DATA}/projects/<hash>/branches/<branch>/state.json` (within `scaffold-claude-agent-scaffolding`) |
| Hooks | SessionStart (always-on protocol) + PreToolUse (Edit/Write/NotebookEdit enforcement) | SessionStart only (project context injection when scaffold-managed) |
| MCP server | none | `scaffold-memory` |
| Skill triggers | "z1", "z2", "show me", "stuck", `/quiz`, `/eli10`, `/fool`, etc. | "/scaffold-…", "slice phase", "ADR", "audit my repo", "recall decision", etc. |

**Behavioral compositions** documented in scaffold/SKILL.md:
- Spec authoring (`/slice-spec`) is Curve 1 (template-driven, mechanical) → run in `/z1` or `ambient`.
- AC capture from a Socratic discussion is Curve 2/decide → run in `/z2-decide`, then `/locked` and proceed to `/slice-contract`.
- Test scaffolding (`/slice-contract`) is Curve 1 → ambient.
- Implementation (`/slice-implement`) — depends on user's mode: side project = `/z2-build`; daily work = `/z1` after thinking is locked.
- Memory recall is read-only, so always allowed.
- ADR/changelog/runbook authoring is Curve 1 — but the *decisions* leading to them may have been Curve 2; the artifact-writing itself is mechanical.

---

## 11. Risks

- **R1 (high):** Phase gates are too strict for real workflows; users `/slice-reset` constantly. *Mitigation:* ship `/slice-reset` early; make gate error messages helpful (always suggest the corrective action); collect override frequency (deferred — see B-series).
- **R2 (medium):** Python venv install on first plugin use is fragile (Python 3.11+ required, network dependency for pip). *Mitigation:* `scripts/install.sh` checks Python version and venv creation up front; emits clear error and skips MCP server registration (degrading to no-memory-bank mode) if setup fails. Plugin still works for slice/init/audit/CLAUDE.md without MCP.
- **R3 (medium):** Ollama dependency confusing — users without Ollama will get "semantic search unavailable" warnings. *Mitigation:* warning is one-time per session; reindex command is documented; FTS5 fallback is genuinely useful (not a degraded experience).
- **R4 (medium):** `repo-hash` strategy choice — using path-based hash means moving the repo dir orphans the state. *Mitigation:* hash on git remote URL when available, fallback to path. Document the limitation.
- **R5 (low):** Worktree forking creates a worktree dir adjacent to the repo (`../<repo>-<branch>`) which may collide with other dirs. *Mitigation:* `--path` flag for explicit placement; default path includes repo name to reduce collision risk.
- **R6 (low):** CLAUDE.md generation overwrites manual edits silently. *Mitigation:* timestamp footer; rebuild warns on manual-edit detection (v1) and offers save-back (v1.1).
- **R7 (low):** Memory bank grows unbounded. *Mitigation:* SQLite handles GB-scale; v1.1 add `/scaffold-memory-prune` if needed.

---

## 12. Verification (test scenarios)

Mirrors ai-mentor's `tests/test-hooks.sh` pattern. Will live at `scaffold/tests/`.

**`test-state.sh`:**
- Branch state file create / read / update / partial update preserves other fields
- Repo-hash determinism: same repo → same hash; renamed dir but same git remote → same hash
- Multi-branch state isolation: writing to branch A doesn't touch branch B

**`test-claude-md.sh`:**
- Personal-defaults file missing → seeded from template
- Project layer missing → seeded from template
- Generation: concatenation order, footer timestamp, line endings
- Manual-edit detection: footer timestamp out of sync vs. mtime → warn

**`test-slice-gates.sh`:**
- `/slice-new` from empty state → phase=spec
- `/slice-contract` without spec_path → refused with helpful message
- `/slice-implement` without failing tests → refused
- `/slice-verify` runs test command, parses output, updates AC status
- `/slice-reset` clears phase but preserves files

**`test-audit.sh`:**
- README detection (with/without Quickstart heading)
- Stack detection: Python / Node / Rust / Go signals
- LLM signal detection: each catalog entry triggers flag
- Audit table output format

**`test-mcp.sh`:**
- Server startup (subprocess; check stderr for "ready")
- `record_decision` → DB insert + FTS index + embedding (or NULL if Ollama missing)
- `recall` semantic: query → top hits ranked
- `recall` FTS5-only fallback: simulate Ollama missing
- `update` re-embeds when body changes
- `delete` removes from all three tables (memory, FTS, vec)

Verification flow is identical to ai-mentor: `bash scaffold/tests/test-*.sh`. CI-friendly exit codes.

---

## 13. Open questions

These are the gaps surfaced during writing. Each has my recommended default; user pushes back if disagrees.

| # | Question | Recommended default | Why |
|---|---|---|---|
| **OQ-1** | **Repo-hash strategy.** Using full git remote URL or path? | **Git remote URL when present, fallback to absolute path.** Both via SHA-256 truncated to 12 chars. | Remote-based survives dir moves; path fallback handles uninitialized repos. |
| **OQ-2** | **Default test-framework when none detected.** Refuse `/slice-contract` or default to a guess? | **Refuse with helpful message.** Suggest one based on stack detection, but require user to explicitly opt in by writing config (e.g., `pytest.ini` for Python). | Auto-installing test infra is too presumptuous. |
| **OQ-3** | **Slice numbering scope — per-branch or global?** If branch A has slices 1-5, branch B forked at slice 3 — does B's next slice get 4 or 6? | **Per-branch numbering.** Each branch starts fresh from its parent's last completed slice number. Forks reset on the new branch from the parent's current count. | Avoids cross-branch number collisions when slices are different concepts. |
| **OQ-4** | **CLAUDE.md commit policy default.** User globally gitignores it. Do we explicitly add it to repo's `.gitignore` on `/scaffold-init` if it's not there, or rely on global? | **Don't touch repo .gitignore for CLAUDE.md.** User has a global gitignore handling it. Document that if the user wants to commit it on a specific repo, they remove it from global gitignore for that path. | Don't surprise the user by adding to repo-level gitignore; respect their global config. |
| **OQ-5** | **Personal-defaults file editing.** When user runs `/scaffold-claude-md-edit personal`, does the editor open in foreground (blocks Claude session) or background (return immediately, regenerate when user signals done)? | **Foreground via `$EDITOR`.** If `$EDITOR` is unset, fall back to opening the file path and asking user to edit + signal "done". | Foreground is the standard editor pattern; less complexity than file-watching. |
| **OQ-6** | **Audit output format.** Markdown table to terminal only, or also save to `docs/AUDIT.md`? | **Terminal by default, `--save` flag writes to `docs/AUDIT.md`.** | Don't pollute the repo on every audit. |
| **OQ-7** | **MCP server: Python venv location.** Bundled with plugin (volatile across updates) or in plugin data (persistent)? | **Plugin data: `${CLAUDE_PLUGIN_DATA}/venv/`.** Created by `scripts/install.sh` once; persists across plugin updates so we don't reinstall on every update. | Faster updates; respects the docs' recommendation. |
| **OQ-8** | **Slice spec template — opinionated or minimal?** | **Opinionated: header sections for User Story, Acceptance Criteria (numbered checkbox list), Constraints, Non-Goals, Design Notes, Open Questions.** Same shape as the plan files visible in `~/.claude/plans/`. | The user's plan files demonstrate this is their preferred shape. |
| **OQ-9** | **Hook: PreToolUse blocking?** Should we add gate enforcement at the tool layer (block writes to `docs/adr/` outside `/adr-new`)? | **No.** Slash commands enforce gates; PreToolUse hook would be too invasive and conflict with ai-mentor's hook semantics. | KISS; rely on slash command discipline. |
| **OQ-10** | **`/slice-new` after a slice is in-progress.** Allow concurrent slices on the same branch, or refuse until current is complete? | **Refuse by default; allow with `--force` flag** that suspends the current slice and starts a new one. | Concurrent slices on one branch is footgun territory. |
| **OQ-11** | **MCP server first-run install.** `scripts/install.sh` creates the venv. Run it manually after `/plugin install`, or self-install on first MCP tool invocation? | **Self-install via `mcp/run-server.sh`.** On launch, check for venv at `${CLAUDE_PLUGIN_DATA}/venv/`; if missing, run `scripts/install.sh` inline (logs to `${CLAUDE_PLUGIN_DATA}/install.log`). User sees a one-time delay on first MCP tool use; no manual step. | Manual install steps are forgotten; self-install matches the no-friction install ergonomic of `ai-mentor`. |
| **OQ-12** | **Slice state import on `/scaffold-init` in an existing scaffold-shaped repo.** If user has `docs/slices/slice-NN-*.md`, `tests/`, and code already, do we walk the filesystem and reconstruct slice state, or start fresh? | **Start fresh in v1.** Document `--import-slices` as v1.1. Filesystem reconstruction is heuristic-heavy (which tests map to which AC?) and gets things wrong silently. | Avoid wrong-state-by-default. User can manually `/slice-new` with the same name to re-establish tracking. |
| **OQ-13** | **MCP `delete` tool: confirmation required?** Should the model be able to delete memory entries autonomously, or require user ack? | **No confirmation; document as permanent.** The model should not delete entries unless explicitly asked by the user — and if user explicitly asks, they've given the ack. | Adding ack inside an MCP tool is friction; trust the model's discretion + user's explicit prompt. |
| **OQ-14** | **Cross-clone state sharing.** Two independent clones of the same git remote (not worktrees — separate `git clone` operations) hash to the same `repo-hash` and share state. Intentional? | **Intentional in v1; document as known behavior.** This is desirable for worktrees and ergonomic for "one repo, two laptops" scenarios (memory bank semantically transfers via `${CLAUDE_PLUGIN_DATA}` cloud sync if user has any). Document. | Distinguishing clones from worktrees would require fingerprinting the working tree, adding fragility. |
| **OQ-15** | **Slice numbering format.** Use 2-digit zero-padded (`slice-04`) up to 99, then 3-digit beyond? Or unpadded (`slice-4`)? | **2-digit padded for 1–99, 3-digit for 100+.** Matches the user's existing plan-files dir convention. | Lexicographic sort matches numeric sort with padding. |

These are **all defaultable** — none block the build. The user can override any in the build kickoff message.

---

## 14. Build sequence

Phased build with review gates. Mirrors ai-mentor's A-L pattern. Each phase is a commit.

| Phase | Deliverable | Tests |
|---|---|---|
| **A** | Plugin scaffold: `plugin.json`, `hooks/hooks.json`, `commands/` stubs (all 18 .md files, empty bodies), `lib/` stubs, `mcp/` skeleton, `templates/` populated, `scripts/install.sh` skeleton, `README.md`, `LICENSE`, `CHANGELOG.md`. | (none yet) |
| **B** | `lib/state.sh`, `lib/repo.sh`, `lib/claude-md.sh`. Implements state schema, repo-hash, branch detection, stack detection, CLAUDE.md generator. | `tests/test-state.sh`, `tests/test-claude-md.sh` |
| **C** | `/scaffold-init`, `/scaffold-status`, `/scaffold-audit`, `/scaffold-claude-md-edit`, `/scaffold-claude-md-rebuild`. Capability 1 + 4. | `tests/test-audit.sh` |
| **D** | `lib/slice.sh` + slice commands (`/slice-new`, `/slice-spec`, `/slice-contract`, `/slice-scaffold`, `/slice-implement`, `/slice-verify`, `/slice-status`, `/slice-list`). Capability 2. | `tests/test-slice-gates.sh` |
| **E** | Governance commands (`/adr-new`, `/changelog`, `/runbook-new`). Capability 3. | (extend test-state.sh with adr_counter test) |
| **F** | `mcp/` Python implementation. SQLite + sqlite-vec + Ollama. 9 MCP tools. `scripts/install.sh`. | `tests/test-mcp.sh` |
| **G** | Worktree commands (`/scaffold-worktree-fork`, `/scaffold-worktree-list`). | (extend test-state.sh with fork test) |
| **H** | SessionStart hook (project-context injection when scaffold-managed). SKILL.md. | (manual smoke test) |
| **I** | End-to-end smoke test on a real fresh repo + a real existing repo. Iterate on rough edges. | E2E pass |
| **J** | Bump to v1.0.0. Update SPEC. Push to GitHub. User installs via marketplace. | — |

**Estimated commits: ~10 (one per phase).** Phases A-E are pure shell; F adds Python; G-J integrate.

The build can be paused after any phase (e.g., ship A-E as v0.5 if Python infra is blocked on Ollama setup). Phases F (MCP), G (worktree), H (SessionStart) are independently scoped enough to defer if needed.

---

## 15. Iteration log

- **v0.1 (2026-04-26):** First-pass spec drafted after the architecture conversation that locked: 4 capabilities, strict phase gates, name `scaffold`, project state at `<repo>/.claude/scaffold/` + plugin-data hybrid, Python MCP server with semantic search via Ollama+nomic-embed-text, 4 memory entry types (decisions/patterns/notes/retrospectives), two-layer CLAUDE.md (personal+project), worktree forking via `/scaffold-worktree-fork`. 18 slash commands + 9 MCP tools + 1 SessionStart hook (no PreToolUse). 10 open questions OQ-1..OQ-10 with recommended defaults; all defaultable.
