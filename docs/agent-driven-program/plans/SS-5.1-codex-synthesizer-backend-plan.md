# SS-5.1 — Optional Codex Synthesizer Backend Implementation Plan

> **For agentic workers:** Build **inline** (single session, sequential W1→W7) per the spec's build-method decision. REQUIRED SUB-SKILL: `superpowers:test-driven-development` — every task is RED (write failing test) → GREEN (implement) → commit. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an **optional Codex synthesizer backend** to scaffold-onboard's three synthesis-dispatch skills (`scaffolding-memory-bank §13`, `scaffolding-governance-docs §11`, `onboarding-project §8`). When the resolved `synthesizer_backend` is `codex`, each synthesis artifact dispatches to the `codex-plugin-cc` companion via a new `lib/codex.sh` instead of the Claude `synthesis-agent` subagent. Default stays `claude_subagent`. Ship `scaffold-onboard` v0.9.0.

**Architecture:** Port SS-5's `lib/codex.sh` async-dispatch spine **minus** worktree / no-commit / gaps-mode (spec §3, §4). One adapter, **prompt-source-agnostic** — `sf_synth_brief_assemble` (13 derivation docs + EXEC-SUMMARY) and `sf_synth_master_spec_prompt` (MASTER-SPEC) both feed the same `sf codex_dispatch`. The backend branch wraps **only the dispatch**; prompt assembly and post-validation stay shared and backend-agnostic. The **router-file boundary** (CLAUDE.md / settings.json / AGENTS.md stay mechanical) is the load-bearing constraint (spec §3.6).

**Tech stack:** Bash (`sf_` libs, `set -u`), Markdown skill bodies, the scaffold-onboard bash test harness, `jq`, `node` (mock companion shim only). Dual-published (Claude `.claude-plugin/` + Codex `.codex-plugin/`).

**Design doc:** `docs/agent-driven-program/specs/SS-5.1-codex-synthesizer-backend.md`
**Branch:** `feat/ss5.1-codex-synthesizer-backend` (create at execution start off `main`).

**Key facts confirmed during planning:**
- **`sf_manifest_get` goes in `lib/routing.sh`** (refines spec §3.7's "new `lib/manifest.sh`"): scaffold-onboard already owns `sf_discover_manifest` there — reuse it, don't duplicate discovery. scaffold-onboard has **no** `sf_jq_get`; read fields with `jq -r "<expr> // empty"` directly (the routing.sh idiom).
- **Harness conventions (scaffold-onboard `tests/_helpers.sh`):** `assert_eq "<label>" "<expected>" "<actual>"` (**label first** — opposite of a bare value); `setup_tmp_workspace_init [proj] [type] [roadmap]` builds `<tmp>/<proj>-ai/.workspace/pairing.json` + `<tmp>/<proj>/` and exports `TMP_AI_WORKSPACE`/`TMP_CANONICAL`/`TMP_MANIFEST` (does **not** cd); `setup_tmp_repo` cds into a plain git repo with **no** manifest; suites end with `report_results` (not `sd_test_summary`); there is **no** `assert_contains` — grep manually + `assert_eq`. The dispatcher is `bin/sf` (`SF_BIN="$HERE/../bin/sf"`).
- **`sf_log_error` only logs** — it does not exit or return non-zero (obs 3174). The ported helpers keep their explicit `return 1` after each `sf_log_error` (matching scaffold-dev's `sd_log_error` discipline).
- **Drop entirely from the port:** `sd_codex_verify_nocommit` (no no-commit boundary) and all worktree handling. **Rename:** `_sd_codex_worktree_trusted` → `_sf_codex_dir_trusted` (it checks any dir, now an output repo root, not a worktree). **Add:** `sf_codex_target_root <out-path>` (git toplevel containing the artifact, robust to a not-yet-created output dir).
- **`sf_codex_result` is unchanged in substance** — it extracts the last fenced `{mode,…}` block and validates `.mode` exists; the synthesis shape `{mode, output_path, ids_minted, ids_cited, summary}` satisfies it identically. The shim's default `result.rawOutput` must be **synthesis-shaped** (not the implementer shape).
- **Memory-bank §13 dispatch** is the canonical seam shape (read: `prompt="$(sf_synth_brief_assemble …)"` → `Task(synthesis-agent …)` → `sf_synth_ledger_merge` + the 3 `sf_synth_assert_*`). Governance §11 mirrors it. Onboarding §8 has **two** sites with bespoke post-validation (MASTER-SPEC: `sf spec_validate` + backup/restore + architect-critic; EXEC-SUMMARY: `sf_render_executive_summary_from_synthesized`) — all of which stay **outside** the backend branch.
- **State coupling:** the companion keys job state by `sha256(git-toplevel-of-cwd)` under `$CLAUDE_PLUGIN_DATA`; every helper `cd`s into the target root before `node`, and `CLAUDE_PLUGIN_DATA` must be stable across dispatch+polls (the harness `setup_tmp_*` already export a stable one).

**Verification commands:**
- Single file: `cd scaffold-onboard && bash tests/<file>`
- Full suite: `cd scaffold-onboard && bash run-tests.sh` (**slow — 55–75s+ per suite**; run backgrounded, generous timeout)
- Dual-publish parity: `bash tests/test-codex-dual-publish.sh` (repo root) — after the version bump
- Router-boundary residue check: `grep -n 'codex_dispatch' scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md` then confirm CLAUDE.md/settings.json/AGENTS.md are NOT among dispatched artifacts

---

## Phase A — Config foundation (backend selection)

### Task W1: Add `sf_manifest_get` to `lib/routing.sh` (field reader, set-e-safe)

**Files:**
- Modify: `scaffold-onboard/lib/routing.sh`
- Create: `scaffold-onboard/tests/test-manifest.sh`

- [ ] **Step 1: Write the failing tests.** Create `tests/test-manifest.sh`:

```bash
#!/usr/bin/env bash
# tests/test-manifest.sh — sf_manifest_get field reader (SS-5.1). Dispatcher-path
# for the set -e-sensitive absent-field read.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
SF_BIN="$HERE/../bin/sf"

test_get_present_field() {
  echo "test_get_present_field:"
  setup_tmp_workspace_init
  local tmp="$TMP_MANIFEST.new"
  jq '.synthesizer_backend = "codex"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  local out rc
  out="$(cd "$TMP_AI_WORKSPACE" && bash "$SF_BIN" manifest_get '.synthesizer_backend')" && rc=0 || rc=$?
  assert_eq "rc=0 on present field" "0" "$rc"
  assert_eq "echoes the field value" "codex" "$out"
}

test_get_absent_field_rc1() {
  echo "test_get_absent_field_rc1:"
  setup_tmp_workspace_init   # no synthesizer_backend field
  local out rc
  out="$(cd "$TMP_AI_WORKSPACE" && bash "$SF_BIN" manifest_get '.synthesizer_backend' 2>/dev/null)" && rc=0 || rc=$?
  assert_eq "rc=1 on absent field" "1" "$rc"
  assert_eq "no output on absent field" "" "$out"
}

test_get_no_manifest_rc1_no_abort() {
  echo "test_get_no_manifest_rc1_no_abort:"
  setup_tmp_repo   # plain git repo, no .workspace/pairing.json
  local out rc
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" manifest_get '.synthesizer_backend' 2>/dev/null)" && rc=0 || rc=$?
  assert_eq "rc=1 when no manifest (must not abort under set -e)" "1" "$rc"
}

test_get_present_field
test_get_absent_field_rc1
test_get_no_manifest_rc1_no_abort
report_results
```

- [ ] **Step 2: Run to verify fail.** `cd scaffold-onboard && bash tests/test-manifest.sh` → FAIL (`Unknown function: sf_manifest_get`).

- [ ] **Step 3: Implement** — append to `lib/routing.sh` (right after `sf_discover_manifest`):

```bash
# ----------------------------------------------------------------------------
# sf_manifest_get <jq-path>  (SS-5.1)
# ----------------------------------------------------------------------------
# Read a scalar field from the discovered manifest. Echoes the value + rc=0;
# rc=1 (no output) when there is no manifest OR the field is absent/null.
# set -e-safe: callers capture rc=1 with `if v="$(sf_manifest_get …)"; then …`.
sf_manifest_get() {
  local expr="$1" manifest out
  if ! manifest="$(sf_discover_manifest)"; then
    return 1
  fi
  out="$(jq -r "${expr} // empty" "$manifest" 2>/dev/null)"
  if [[ -z "$out" || "$out" == "null" ]]; then
    return 1
  fi
  echo "$out"
}
```

- [ ] **Step 4: Run to verify pass.** `cd scaffold-onboard && bash tests/test-manifest.sh` → PASS (3/0).

- [ ] **Step 5: Commit.**
```bash
git add scaffold-onboard/lib/routing.sh scaffold-onboard/tests/test-manifest.sh
git commit -m "feat(scaffold-onboard): add sf_manifest_get field reader to routing.sh (SS-5.1)"
```

### Task W2: Add `lib/backend.sh` — `sf_backend_resolve`

**Files:**
- Create: `scaffold-onboard/lib/backend.sh`
- Create: `scaffold-onboard/tests/test-backend.sh`

- [ ] **Step 1: Write the failing tests** (port scaffold-dev's `test-backend.sh`, adapted to the scaffold-onboard harness — `setup_tmp_workspace_init`, `assert_eq` label-first, manual grep for stderr, `report_results`):

```bash
#!/usr/bin/env bash
# tests/test-backend.sh — sf_backend_resolve (SS-5.1 synthesizer selector).
# Dispatcher-path (bin/sf) for the set -e-sensitive manifest-read default.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
SF_BIN="$HERE/../bin/sf"

test_default_when_field_absent() {
  echo "test_default_when_field_absent:"
  setup_tmp_workspace_init
  local out rc
  out="$(cd "$TMP_AI_WORKSPACE" && bash "$SF_BIN" backend_resolve)" && rc=0 || rc=$?
  assert_eq "rc=0" "0" "$rc"
  assert_eq "defaults to claude_subagent" "claude_subagent" "$out"
}

test_field_codex() {
  echo "test_field_codex:"
  setup_tmp_workspace_init
  local tmp="$TMP_MANIFEST.new"
  jq '.synthesizer_backend = "codex"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  local out rc
  out="$(cd "$TMP_AI_WORKSPACE" && bash "$SF_BIN" backend_resolve)" && rc=0 || rc=$?
  assert_eq "rc=0" "0" "$rc"
  assert_eq "reads codex from manifest" "codex" "$out"
}

test_override_beats_manifest() {
  echo "test_override_beats_manifest:"
  setup_tmp_workspace_init
  local tmp="$TMP_MANIFEST.new"
  jq '.synthesizer_backend = "codex"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  local out rc
  out="$(cd "$TMP_AI_WORKSPACE" && bash "$SF_BIN" backend_resolve --backend claude_subagent)" && rc=0 || rc=$?
  assert_eq "override beats a SET manifest field" "claude_subagent" "$out"
}

test_override_missing_value_rc2() {
  echo "test_override_missing_value_rc2:"
  setup_tmp_workspace_init
  local out rc
  out="$(cd "$TMP_AI_WORKSPACE" && bash "$SF_BIN" backend_resolve --backend 2>&1)" && rc=0 || rc=$?
  assert_eq "rc=2 when --backend lacks a value" "2" "$rc"
  printf '%s' "$out" | grep -q "missing value for --backend" && assert_eq "names the error" "ok" "ok" || assert_eq "names the error" "ok" "MISSING"
}

test_no_manifest_defaults_no_abort() {
  echo "test_no_manifest_defaults_no_abort:"
  setup_tmp_repo   # no manifest on the walk-up path; manifest-read rc1 must not abort under set -e
  local out rc
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" backend_resolve)" && rc=0 || rc=$?
  assert_eq "rc=0 (manifest-read rc1 does not abort)" "0" "$rc"
  assert_eq "defaults to claude_subagent" "claude_subagent" "$out"
}

test_invalid_backend_rc1() {
  echo "test_invalid_backend_rc1:"
  setup_tmp_repo
  local out rc
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" backend_resolve --backend bogus 2>&1)" && rc=0 || rc=$?
  assert_eq "rc=1 on invalid backend" "1" "$rc"
  printf '%s' "$out" | grep -q "bogus" && assert_eq "names the invalid value" "ok" "ok" || assert_eq "names the invalid value" "ok" "MISSING"
}

test_default_when_field_absent
test_field_codex
test_override_beats_manifest
test_override_missing_value_rc2
test_no_manifest_defaults_no_abort
test_invalid_backend_rc1
report_results
```

- [ ] **Step 2: Run to verify fail.** → FAIL (`Unknown function: sf_backend_resolve`).

- [ ] **Step 3: Implement** `lib/backend.sh` (port of scaffold-dev's, `sd_`→`sf_`, field `.synthesizer_backend`, sources `routing.sh` for `sf_manifest_get`):

```bash
#!/usr/bin/env bash
# scaffold-onboard/lib/backend.sh
# SS-5.1 — synthesizer backend selector. Resolves which backend runs a synthesis
# dispatch: a per-invocation override, else the manifest's optional
# `.synthesizer_backend`, else the default `claude_subagent`. Read-with-default
# only — absent field / absent manifest resolve to claude_subagent (existing
# projects unchanged; no workspace-init schema change required).
#
# set -e safety: sf_manifest_get returns rc=1 when the field/manifest is absent —
# captured set-e-safe so the default does not abort under bin/sf's set -euo pipefail.
set -u

_SF_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sf_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SF_LIB_DIR/_helpers.sh"
fi
if ! declare -F sf_manifest_get >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SF_LIB_DIR/routing.sh"
fi

# sf_backend_resolve [--backend <override>]
# Echoes the resolved backend (claude_subagent | codex). Precedence:
#   --backend override  >  manifest .synthesizer_backend  >  claude_subagent
# rc=0 on a valid backend; rc=1 on an invalid value; rc=2 on bad usage.
sf_backend_resolve() {
  local override=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backend)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          sf_log_error "sf_backend_resolve: missing value for --backend"
          return 2
        fi
        override="$2"; shift 2 ;;
      *) sf_log_error "sf_backend_resolve: unknown arg: $1"; return 2 ;;
    esac
  done

  local resolved=""
  if [[ -n "$override" ]]; then
    resolved="$override"
  else
    local field=""
    if field="$(sf_manifest_get '.synthesizer_backend' 2>/dev/null)"; then :; else field=""; fi
    if [[ -n "$field" && "$field" != "null" ]]; then
      resolved="$field"
    else
      resolved="claude_subagent"
    fi
  fi

  case "$resolved" in
    claude_subagent|codex) echo "$resolved"; return 0 ;;
    *) sf_log_error "sf_backend_resolve: invalid backend '$resolved' (expected claude_subagent|codex)"; return 1 ;;
  esac
}
```

- [ ] **Step 4: Run to verify pass.** → PASS (6/0).

- [ ] **Step 5: Commit.**
```bash
git add scaffold-onboard/lib/backend.sh scaffold-onboard/tests/test-backend.sh
git commit -m "feat(scaffold-onboard): add sf_backend_resolve synthesizer selector (SS-5.1)"
```

---

## Phase B — Codex adapter

### Task W3: Port the mock companion shim (synthesis-shaped result)

**Files:**
- Create: `scaffold-onboard/tests/fixtures/codex-shim/codex-companion.mjs`

- [ ] **Step 1:** Copy `scaffold-dev/tests/fixtures/codex-shim/codex-companion.mjs` verbatim, with **one change** — the default `result` rawOutput must be **synthesis-shaped**:

```js
  case "result": {
    const raw =
      process.env.CODEX_SHIM_RESULT_RAWOUTPUT ??
      'Synthesis complete.\n\n```json\n{"mode":"complete","output_path":"/tmp/out.md","ids_minted":{"use_cases":[],"frs":[],"nfrs":[],"backlog":[]},"ids_cited":[],"summary":"synthesized one artifact"}\n```\n';
    out({ job: { id: jobId, status: "completed" }, storedJob: { result: { rawOutput: raw } } });
    break;
  }
```

All other cases (`setup`/`task`/`status`/`cancel`) and the env contract (`CODEX_SHIM_LOG`/`_JOBID`/`_SETUP`/`_STATUS`/`_STATUS_RAW`/`_LOGFILE`/`_RESULT_RAWOUTPUT`/`_FAIL`/`_NO_JOBID`) are unchanged. Update the header comment to say "scaffold-onboard tests (SS-5.1)".

- [ ] **Step 2:** No standalone test — W4 exercises it. Sanity: `node scaffold-onboard/tests/fixtures/codex-shim/codex-companion.mjs setup --json | jq -e '.ready'` → `true`.

- [ ] **Step 3: Commit.**
```bash
git add scaffold-onboard/tests/fixtures/codex-shim/codex-companion.mjs
git commit -m "test(scaffold-onboard): port codex-companion mock shim, synthesis-shaped result (SS-5.1)"
```

### Task W4: Port `lib/codex.sh` (resolve / target_root / preflight / dispatch / wait / result)

**Files:**
- Create: `scaffold-onboard/lib/codex.sh`
- Create: `scaffold-onboard/tests/test-codex.sh`

**Port recipe** (from `scaffold-dev/lib/codex.sh`, `sd_`→`sf_`, `_SD_`→`_SF_`):

| Function | Action |
|---|---|
| header comment | adapt: "implementer backend" → "synthesizer backend"; "worktree" → "target root (output repo)"; remove the no-commit paragraph; keep the LOAD-BEARING set-e + state-coupling notes |
| `_sf_codex_default_cache_dirs`, `_sf_codex_version_gt`, `sf_codex_resolve_companion` | **verbatim** (rename only) |
| `_sf_codex_dir_trusted <dir>` | = `_sd_codex_worktree_trusted` renamed; param `wt`→`dir`; logic identical (path-prefix trust check vs `~/.codex/config.toml`) |
| `sf_codex_preflight <target-root>` | = `sd_codex_preflight` renamed; param `wt`→`target_root`; calls `_sf_codex_dir_trusted`; reword messages "worktree" → "output repo / target root" |
| `_sf_codex_require_value`, `_sf_codex_require_nonnegative_int` | **verbatim** |
| `sf_codex_dispatch <target-root> <prompt-file> [--model M --effort E --resume-last/--resume/--fresh]` | = `sd_codex_dispatch` renamed; param `wt`→`target_root`; identical (cd into `target_root` before `node`; keep all flag plumbing — re-dispatch-once may use `--resume-last`) |
| `_sf_codex_mtime`, `sf_codex_wait <target-root> <job-id> […]`, `_sf_codex_cancel`, `sf_codex_result <target-root> <job-id>` | **verbatim** (rename only — non-throwing wait loop + fenced-`{mode,…}` extraction unchanged) |
| `sd_codex_verify_nocommit` | **DROP — do not port** |
| `sf_codex_target_root <out-path>` | **NEW** (below) |

The new helper:

```bash
# sf_codex_target_root <out-path>  (SS-5.1)
# Echo the repo root Codex should run in so sandbox=workspace-write covers the
# write to <out-path>: the git toplevel containing the (possibly not-yet-created)
# output path, else its nearest existing ancestor dir. rc=1 if none resolvable.
sf_codex_target_root() {
  local out="${1:-}"
  if [[ -z "$out" ]]; then
    sf_log_error "sf_codex_target_root: output path required"; return 1
  fi
  local dir; dir="$(dirname "$out")"
  while [[ -n "$dir" && "$dir" != "/" && ! -d "$dir" ]]; do dir="$(dirname "$dir")"; done
  if [[ ! -d "$dir" ]]; then
    sf_log_error "sf_codex_target_root: no existing ancestor dir for: $out"; return 1
  fi
  local root
  if root="$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$root" ]]; then
    echo "$root"; return 0
  fi
  ( cd "$dir" && pwd -P )
}
```

- [ ] **Step 1: Write the failing tests** — `tests/test-codex.sh`. Header (note the **node skip-guard**, the SS-5 lesson) + representative high-risk cases; mirror scaffold-dev's `test-codex.sh` coverage adapted to the scaffold-onboard harness, **all through `bin/sf`**:

```bash
#!/usr/bin/env bash
# tests/test-codex.sh — lib/codex.sh synthesis adapter (SS-5.1). Mock companion
# via SCAFFOLD_CODEX_COMPANION; dispatcher-path (bin/sf) for set -e safety.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
SF_BIN="$HERE/../bin/sf"
SHIM="$HERE/fixtures/codex-shim/codex-companion.mjs"
export SCAFFOLD_CODEX_COMPANION="$SHIM"

if ! command -v node >/dev/null 2>&1; then
  echo "test-codex.sh: SKIP — node not found (codex_* helpers exec node <companion>)"; exit 0
fi

# resolve: override wins
test_resolve_override() {
  echo "test_resolve_override:"
  local out rc
  out="$(bash "$SF_BIN" codex_resolve_companion)" && rc=0 || rc=$?
  assert_eq "rc=0" "0" "$rc"
  assert_eq "echoes the override shim path" "$SHIM" "$out"
}

# target_root: git repo → toplevel
test_target_root_git_toplevel() {
  echo "test_target_root_git_toplevel:"
  setup_tmp_repo   # cwd = a git repo at $TMP_DIR/repo
  local out rc
  out="$(bash "$SF_BIN" codex_target_root "$TMP_DIR/repo/.claude/memory-bank/00-project-brief.md")" && rc=0 || rc=$?
  assert_eq "rc=0" "0" "$rc"
  assert_eq "resolves to the git toplevel" "$(cd "$TMP_DIR/repo" && pwd -P)" "$out"
}

# preflight: untrusted target root → rc=1 (CODEX_HOME with a config naming a different trusted root)
test_preflight_untrusted_dir() {
  echo "test_preflight_untrusted_dir:"
  setup_tmp_repo
  export CODEX_HOME="$TMP_DIR/codex-home"; mkdir -p "$CODEX_HOME"
  printf '[projects."/some/other/trusted"]\ntrust_level = "trusted"\n' > "$CODEX_HOME/config.toml"
  local rc
  ( cd "$TMP_DIR/repo" && bash "$SF_BIN" codex_preflight "$TMP_DIR/repo" >/dev/null 2>&1 ) && rc=0 || rc=$?
  unset CODEX_HOME
  assert_eq "rc=1 when target root is outside all trusted roots" "1" "$rc"
}

# wait: status=failed is non-throwing (rc=0, token "failed") — the highest-risk set -e surface
test_wait_failed_nonthrowing() {
  echo "test_wait_failed_nonthrowing:"
  setup_tmp_repo
  export CODEX_SHIM_STATUS="failed"
  local out rc
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" codex_wait "$TMP_DIR/repo" task-shim001 --poll 0)" && rc=0 || rc=$?
  unset CODEX_SHIM_STATUS
  assert_eq "rc=0 (non-throwing under set -e)" "0" "$rc"
  assert_eq "token is failed" "failed" "$out"
}

# wait: legacy done → normalized completed
test_wait_done_normalized() {
  echo "test_wait_done_normalized:"
  setup_tmp_repo
  export CODEX_SHIM_STATUS="done"
  local out
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" codex_wait "$TMP_DIR/repo" task-shim001 --poll 0)"
  unset CODEX_SHIM_STATUS
  assert_eq "done normalized to completed" "completed" "$out"
}

# dispatch: echoes job-id; logs --write/--background/--prompt-file
test_dispatch_jobid_and_flags() {
  echo "test_dispatch_jobid_and_flags:"
  setup_tmp_repo
  local pf="$TMP_DIR/prompt.md"; printf 'synthesize X\n' > "$pf"
  export CODEX_SHIM_LOG="$TMP_DIR/argv.log"
  local out
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" codex_dispatch "$TMP_DIR/repo" "$pf")"
  assert_eq "echoes shim job id" "task-shim001" "$out"
  grep -q -- '--write' "$CODEX_SHIM_LOG" && grep -q -- '--background' "$CODEX_SHIM_LOG" && grep -q -- '--prompt-file' "$CODEX_SHIM_LOG" \
    && assert_eq "passed --write/--background/--prompt-file" "ok" "ok" || assert_eq "passed flags" "ok" "MISSING"
  unset CODEX_SHIM_LOG
}

# result: extracts the fenced synthesis {mode,…} block
test_result_extracts_synthesis_json() {
  echo "test_result_extracts_synthesis_json:"
  setup_tmp_repo
  local out mode
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" codex_result "$TMP_DIR/repo" task-shim001)"
  mode="$(printf '%s' "$out" | jq -r '.mode')"
  assert_eq "mode is complete" "complete" "$mode"
}

# result: no fenced block → rc=1
test_result_no_fence_rc1() {
  echo "test_result_no_fence_rc1:"
  setup_tmp_repo
  export CODEX_SHIM_RESULT_RAWOUTPUT="just prose, no fence"
  local rc
  ( cd "$TMP_DIR/repo" && bash "$SF_BIN" codex_result "$TMP_DIR/repo" task-shim001 >/dev/null 2>&1 ) && rc=0 || rc=$?
  unset CODEX_SHIM_RESULT_RAWOUTPUT
  assert_eq "rc=1 when no fenced JSON" "1" "$rc"
}

test_resolve_override
test_target_root_git_toplevel
test_preflight_untrusted_dir
test_wait_failed_nonthrowing
test_wait_done_normalized
test_dispatch_jobid_and_flags
test_result_extracts_synthesis_json
test_result_no_fence_rc1
report_results
```

Add the remaining ported cases (mirroring scaffold-dev's `test-codex.sh`): resolve glob-newest + absent-fail; preflight ready→0 / unauthed→1 (`CODEX_SHIM_SETUP` with `ready:false,auth.loggedIn:false`); dispatch `--resume-last`+`--fresh` conflict→rc1, missing prompt-file→rc1, `--model`/`--effort` forwarded; wait stall (`CODEX_SHIM_LOGFILE` old mtime + `--stall 0`)→`stalled`+cancel logged, cap (`--cap 0`)→`capped`, bad option→`error`+rc0, unparseable status (`CODEX_SHIM_STATUS_RAW=notjson`)→`error`; result gaps/failed mode, prose-before-fence, multi-fence→last, fence-without-`.mode`→rc1; target_root non-git dir → nearest ancestor.

- [ ] **Step 2: Run to verify fail.** → FAIL (functions undefined).
- [ ] **Step 3: Implement** `lib/codex.sh` per the port recipe above.
- [ ] **Step 4: Run to verify pass.** `cd scaffold-onboard && bash tests/test-codex.sh` → PASS (all green; node present).
- [ ] **Step 5: Commit.**
```bash
git add scaffold-onboard/lib/codex.sh scaffold-onboard/tests/test-codex.sh
git commit -m "feat(scaffold-onboard): add lib/codex.sh synthesis adapter, ported from scaffold-dev (SS-5.1)"
```

---

## Phase C — Seam rewrites

### Task W5: Derivation seam — `scaffolding-memory-bank §13` + `scaffolding-governance-docs §11`

**Files:**
- Modify: `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md` (§13.2 Wave-4 dispatch + a §13 setup line sourcing the new libs)
- Modify: `scaffold-onboard/skills/scaffolding-governance-docs/SKILL.md` (§11.2 wave dispatch, same pattern)
- Modify: `scaffold-onboard/tests/test-synthesis-dispatch.sh` (structural prose guards)

- [ ] **Step 1: Write the failing structural guards** — append to `test-synthesis-dispatch.sh` and register (uses the file's existing `_extract_section_bash`):

```bash
# SS-5.1 — each derivation seam carries the backend branch and sources its libs.
test_memory_bank_dispatch_has_codex_branch() {
  echo "test_memory_bank_dispatch_has_codex_branch:"
  local body; body="$(_extract_section_bash "$MB_SKILL" "## 13")"
  local ok=1
  printf '%s' "$body" | grep -q 'backend_resolve' || { echo "  ✗ §13 has no sf backend_resolve branch"; ok=0; }
  printf '%s' "$body" | grep -q 'codex_dispatch'  || { echo "  ✗ §13 never dispatches via codex"; ok=0; }
  printf '%s' "$body" | grep -Eq 'source .*/lib/(backend|codex)\.sh' || { echo "  ✗ §13 does not source backend/codex libs"; ok=0; }
  if [[ "$ok" == 1 ]]; then PASS=$((PASS+1)); echo "  ✓ §13 has the codex backend branch + sources its libs"; else FAIL=$((FAIL+1)); fi
}

# SS-5.1 — the Codex branch hard-fails (no silent Claude fallback).
test_memory_bank_codex_branch_hard_fails() {
  echo "test_memory_bank_codex_branch_hard_fails:"
  local body; body="$(_extract_section_bash "$MB_SKILL" "## 13")"
  if printf '%s' "$body" | grep -q 'codex_preflight'; then
    PASS=$((PASS+1)); echo "  ✓ §13 codex path runs preflight (hard-fail, no Claude fallback)"
  else FAIL=$((FAIL+1)); echo "  ✗ §13 codex path missing preflight hard-gate"; fi
}

# SS-5.1 — router files are NEVER routed through codex_dispatch (boundary guard,
# parallel to test_claude_md_mechanically_generated_not_synthesized).
test_router_files_not_codex_dispatched() {
  echo "test_router_files_not_codex_dispatched:"
  local ok=1 f
  for f in "$MB_SKILL"; do
    # No line both names a router file and codex_dispatch.
    if grep -nE 'codex_dispatch' "$f" | grep -Eq 'CLAUDE\.md|settings\.json|AGENTS\.md'; then
      echo "  ✗ a router file is dispatched via codex in $(basename "$(dirname "$f")")"; ok=0
    fi
  done
  # The three mechanical generators remain unconditional (already guarded for CLAUDE.md).
  grep -q 'sf_claude_settings_generate' "$MB_SKILL" && grep -q 'sf_agents_md_generate' "$MB_SKILL" || { echo "  ✗ mechanical router generators missing"; ok=0; }
  if [[ "$ok" == 1 ]]; then PASS=$((PASS+1)); echo "  ✓ router files stay mechanical on the codex path"; else FAIL=$((FAIL+1)); fi
}

test_governance_dispatch_has_codex_branch() {
  echo "test_governance_dispatch_has_codex_branch:"
  local body; body="$(_extract_section_bash "$GOV_SKILL" "## 11")"
  if printf '%s' "$body" | grep -q 'backend_resolve' && printf '%s' "$body" | grep -q 'codex_dispatch'; then
    PASS=$((PASS+1)); echo "  ✓ §11 has the codex backend branch"
  else FAIL=$((FAIL+1)); echo "  ✗ §11 missing codex backend branch"; fi
}
```
Register all four in the runner block. Run → FAIL (no branch yet).

- [ ] **Step 2: Rewrite the §13.2 Wave-4 dispatch** — keep the shared prompt + post-validation, branch only the dispatch. Replace the `Task(...)` standard-pattern block with:

```bash
# Resolve once at §13 setup (alongside the existing state.sh source):
source "${CLAUDE_PLUGIN_ROOT}/lib/backend.sh"   # → sf_backend_resolve (sources routing.sh + codex.sh deps)
source "${CLAUDE_PLUGIN_ROOT}/lib/codex.sh"
backend="$(sf backend_resolve)"
```
and per artifact:
```bash
brief="${CLAUDE_PLUGIN_ROOT}/templates/synthesis-briefs/<NAME>.brief.md"
out="$(sf_resolve_output_path <routes_to> .claude/memory-bank/<name>.md)"
prompt="$(sf_synth_brief_assemble "$brief" "$ledger" "$out" "$master" "$exec_summary")"   # UNCHANGED
if [[ "$backend" == "codex" ]]; then
  target_root="$(sf codex_target_root "$out")"
  sf codex_preflight "$target_root"            # hard-fail; NO Claude fallback
  pf="$(mktemp "${TMPDIR:-/tmp}/sf-codex-prompt.XXXXXX.md")"; printf '%s' "$prompt" > "$pf"
  trap 'rm -f "$pf"' EXIT INT TERM
  job="$(sf codex_dispatch "$target_root" "$pf")"; rm -f "$pf"; trap - EXIT INT TERM
  term="$(sf codex_wait "$target_root" "$job")"
  result="$(sf codex_result "$target_root" "$job")"   # {mode, output_path, ids_minted, ids_cited, summary}
else
  # existing Claude path:
  # Task(subagent_type="scaffold-onboard:synthesis-agent", model="claude-sonnet-4-5", prompt="$prompt")
  result="<the agent's returned JSON>"
fi
# SHARED post-processing (UNCHANGED, runs for both backends):
ledger="$(sf_synth_ledger_merge "$ledger" "<ids_minted from result>")"
sf_synth_assert_sections "$brief" "$out"
sf_synth_assert_no_markers "$out"
sf_synth_validate_cited "$ledger" "<ids_cited from result>"
# on mode:failed OR validator fail → re-dispatch THAT artifact once via the SAME backend → else sf_log_error + stop
```
Keep the `03-code-patterns` preserve-zone extract/reinject **bracketing** the dispatch (unchanged — backend-agnostic). Keep the finalize block (`sf_memory_bank_seed_live_static`, then the three mechanical router generators `sf_claude_md_generate`/`sf_claude_settings_generate`/`sf_agents_md_generate`) exactly as-is — **never** on the codex path. Add a one-line note in the §13 "Supported flags / who does what" area: the synthesizer backend is selected by `sf backend_resolve` (manifest `.synthesizer_backend`); router files stay mechanical.

- [ ] **Step 3: Apply the same branch to `scaffolding-governance-docs §11.2`**, honoring the per-wave ledger threading (PRD→SRS→BACKLOG): the backend branch wraps each wave's dispatch; `sf_synth_ledger_merge` + validators stay shared. Governance routes some artifacts to canonical (PRD/SRS/BACKLOG) and some to ai_workspace (process ADRs) — `sf codex_target_root "$out"` handles each per-artifact (spec §3.2 dual-repo note); preflight runs per-artifact.

- [ ] **Step 4: Run the structural guards + the existing dispatch suite.**

Run: `cd scaffold-onboard && bash tests/test-synthesis-dispatch.sh`
Expected: PASS — new SS-5.1 guards green AND the pre-existing guards (sources-its-helpers, router-file-mechanical, finalize-routes-to-memory_bank, inline-fallback-documented) still green.

- [ ] **Step 5: Commit.**
```bash
git add scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md scaffold-onboard/skills/scaffolding-governance-docs/SKILL.md scaffold-onboard/tests/test-synthesis-dispatch.sh
git commit -m "feat(scaffold-onboard): wire codex synthesizer backend into derivation seams §13/§11 (SS-5.1)"
```

### Task W6: Onboarding seam — `onboarding-project §8` (MASTER-SPEC + EXEC-SUMMARY)

**Files:**
- Modify: `scaffold-onboard/skills/onboarding-project/SKILL.md` (§8 two dispatch sites)
- Modify: `scaffold-onboard/tests/test-synthesis-dispatch.sh` (onboarding guards)

- [ ] **Step 1: Write the failing guards** (register in the runner):

```bash
ONB_SKILL="$ROOT/skills/onboarding-project/SKILL.md"

test_onboarding_master_spec_has_codex_branch() {
  echo "test_onboarding_master_spec_has_codex_branch:"
  local body; body="$(_extract_section_bash "$ONB_SKILL" "## 8")"
  local ok=1
  printf '%s' "$body" | grep -q 'backend_resolve' || { echo "  ✗ §8 has no backend branch"; ok=0; }
  printf '%s' "$body" | grep -q 'codex_dispatch'  || { echo "  ✗ §8 never dispatches via codex"; ok=0; }
  # post-validation stays OUTSIDE the branch: spec_validate + architect-critic must remain.
  printf '%s' "$body" | grep -q 'spec_validate'   || { echo "  ✗ §8 dropped sf spec_validate"; ok=0; }
  printf '%s' "$body" | grep -q 'critiquing-spec' || { echo "  ✗ §8 dropped the architect-critic close gate"; ok=0; }
  if [[ "$ok" == 1 ]]; then PASS=$((PASS+1)); echo "  ✓ §8 MASTER-SPEC codex branch with post-validation preserved"; else FAIL=$((FAIL+1)); fi
}

test_onboarding_exec_summary_writeback_preserved() {
  echo "test_onboarding_exec_summary_writeback_preserved:"
  local body; body="$(_extract_section_bash "$ONB_SKILL" "## 8")"
  if printf '%s' "$body" | grep -q 'sf_render_executive_summary_from_synthesized'; then
    PASS=$((PASS+1)); echo "  ✓ §8 keeps the EXEC-SUMMARY write-back guard (both backends)"
  else FAIL=$((FAIL+1)); echo "  ✗ §8 dropped the EXEC-SUMMARY write-back guard"; fi
}
```
Run → FAIL.

- [ ] **Step 2: Rewrite the MASTER-SPEC dispatch site (§8).** Keep the digest mktemp + `asm_rc` guard + digest-failure hard-stop UNCHANGED. Branch only the dispatch:

```bash
# … existing: prompt="$(sf synth_master_spec_prompt "$brief" "$digest_file" "$master")"; asm_rc=$? ; rm -f "$digest_file"
source "${CLAUDE_PLUGIN_ROOT}/lib/backend.sh"; source "${CLAUDE_PLUGIN_ROOT}/lib/codex.sh"
backend="$(sf backend_resolve)"
if [[ "$backend" == "codex" ]]; then
  target_root="$(sf codex_target_root "$master")"
  sf codex_preflight "$target_root"
  pf="$(mktemp "${TMPDIR:-/tmp}/sf-codex-mspec.XXXXXX.md")"; printf '%s' "$prompt" > "$pf"
  trap 'rm -f "$pf"' EXIT INT TERM
  job="$(sf codex_dispatch "$target_root" "$pf")"; rm -f "$pf"; trap - EXIT INT TERM
  term="$(sf codex_wait "$target_root" "$job")"
  result="$(sf codex_result "$target_root" "$job")"
else
  # Task(subagent_type="scaffold-onboard:synthesis-agent", model="claude-sonnet-4-5", prompt="$prompt")
  result="<agent return>"
fi
```
Everything AFTER the dispatch stays exactly as today and **outside** the branch: `sf spec_validate "$master"` → on fail restore `$master_bak` (or `rm` for first-author) + `status=close_pending` → on pass `Skill(architect-critic:critiquing-spec) target=master-spec-full depth=close artifact_path="$master"`. The existing **inline/headless fallback** prose (which already names Codex as a host) is left intact — it is the orthogonal no-dispatch path.

- [ ] **Step 3: Rewrite the EXEC-SUMMARY dispatch site (§8)** — same branch shape around `prompt="$(sf synth_brief_assemble "$brief" "$(sf synth_ledger_empty)" "$out" "$master" "")"`; keep `sf_render_executive_summary_from_synthesized` write-back **outside** the branch, unchanged.

- [ ] **Step 4: Run guards + the inline-fallback guard** (which already asserts onboarding documents dispatch→inline→re-dispatch→hard-fail):

Run: `cd scaffold-onboard && bash tests/test-synthesis-dispatch.sh`
Expected: PASS — onboarding SS-5.1 guards green; `test_inline_fallback_model_documented` still green.

- [ ] **Step 5: Commit.**
```bash
git add scaffold-onboard/skills/onboarding-project/SKILL.md scaffold-onboard/tests/test-synthesis-dispatch.sh
git commit -m "feat(scaffold-onboard): wire codex synthesizer backend into onboarding §8 MASTER-SPEC + EXEC-SUMMARY (SS-5.1)"
```

---

## Phase D — Release

### Task W7: Version bump, CHANGELOG, program ledger, full-suite + parity gate

**Files:**
- Modify: `scaffold-onboard/.claude-plugin/plugin.json`, `scaffold-onboard/.codex-plugin/plugin.json`
- Modify: `scaffold-onboard/CHANGELOG.md`
- Modify: `docs/agent-driven-program/SPEC-agent-driven-program.md` (§5 add SS-5.1 + §6 ledger)

- [ ] **Step 1:** Bump `"version"` `0.8.0` → `0.9.0` in **both** plugin manifests (identical).
- [ ] **Step 2:** Add a `## [0.9.0]` CHANGELOG section (Keep-a-Changelog): **Added** — optional Codex synthesizer backend (`lib/codex.sh` + `lib/backend.sh` + `sf_manifest_get`) behind manifest `.synthesizer_backend` / `--backend` override, wired into all three synthesis-dispatch skills (§13/§11/§8); router files (CLAUDE.md/settings.json/AGENTS.md) remain mechanically generated, never synthesized (SS-5.1). Default stays `claude_subagent`.
- [ ] **Step 3:** Update `SPEC-agent-driven-program.md`: add the **SS-5.1** row to §5 (shipped — scaffold-onboard v0.9.0) and the §6 ledger row (file + close the SS-5.1 issue). Reference: the SS-5.1 design-of-record spec.
- [ ] **Step 4: Full suite (backgrounded, generous timeout).** `cd scaffold-onboard && bash run-tests.sh` → all `test-*.sh` green incl. new `test-manifest.sh` / `test-backend.sh` / `test-codex.sh` (node-present) + extended `test-synthesis-dispatch.sh`. Confirm the `node`-absent path on `test-codex.sh` emits the loud SKIP, not a hang.
- [ ] **Step 5: Dual-publish parity.** `bash tests/test-codex-dual-publish.sh` (repo root) → both manifests at 0.9.0, parity holds.
- [ ] **Step 6: Router-boundary residue check.** Confirm no `codex_dispatch` line in any skill references `CLAUDE.md` / `settings.json` / `AGENTS.md`.
- [ ] **Step 7: Commit.**
```bash
git add scaffold-onboard/.claude-plugin/plugin.json scaffold-onboard/.codex-plugin/plugin.json scaffold-onboard/CHANGELOG.md docs/agent-driven-program/SPEC-agent-driven-program.md
git commit -m "release(scaffold-onboard): v0.9.0 — SS-5.1 optional Codex synthesizer backend"
```

---

## Post-plan (orchestrator, outside the task loop)

- File the **SS-5.1 GitHub issue** (none exists) before/at W7 so the release closes it; map it in SPEC §6.
- Open PR `feat/ss5.1-codex-synthesizer-backend` → `main`; title references SS-5.1.
- **Adversarial holistic-review Workflow** over the full branch diff (spec §5): lenses for (a) `set -e`-safety re-exercised through `bin/sf` (esp. `sf_codex_wait`), (b) **router-file-boundary conformance**, (c) **companion-fidelity with one lens running a LIVE Codex synthesis** (mock can't prove field-path fidelity), (d) spec-conformance + ledger-threading. Skeptic-per-finding filter.
- Run the **`@codex review` / CodeRabbit** cycle; converge on Codex-clean + green suite (bot-review-convergence judgment). Watch the **upgrade/legacy-input class** (`test_upgrade_input_class`): a manifest WITHOUT `.synthesizer_backend` must resolve to `claude_subagent`; an existing project re-running `/scaffold-project` with the default backend must behave byte-identically to v0.8.0.
- On merge: tag `scaffold-onboard-v0.9.0`, close the SS-5.1 issue, mark SPEC §5/§6 shipped.
- **Real-Codex smoke (operator, post-merge, NOT CI):** throwaway workspace, `.synthesizer_backend=codex`, real Codex authed + target repo trusted → run `/scaffold-docs`; confirm a real synthesis writes a valid artifact passing the validators, an early failure surfaces within a poll interval, and router files stay mechanical.
- Write the session handoff (manual, `docs/agent-driven-program/handoffs/`).
```
