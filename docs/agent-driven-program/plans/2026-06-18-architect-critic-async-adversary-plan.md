# architect-critic Async External Adversary — Phase A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make architect-critic's close-depth external adversary (Codex) runnable as a managed background job — dispatch/status/result/cancel, readiness doctor, durable `state.json` job memory, and defer-to-resume unified rebuttal — while the existing synchronous path stays the untouched default.

**Architecture:** Add an async section to `lib/codex.sh` by porting the proven SS-5/SS-5.1 `codex-companion` spine (`ac_` prefix), driving the `codex-plugin-cc` companion's `task --background` instead of synchronous `codex exec`. Background runs are recorded in a v3 `state.json` (`external_runs[]`); a dedicated `managing-async-critique` skill consumes them via `resume`, which re-enters the *existing* consolidate+rebuttal procedure (critiquing-spec Steps 7–9) with both adversaries present. A standalone doctor skill reports readiness.

**Tech Stack:** Bash (sourced through `bin/arc`, `set -euo pipefail`), `jq`, Node.js (the companion + an env-driven test shim), markdown SKILL.md skill bodies. Tests are bash suites using `tests/_helpers.sh` (`assert_eq`/`report_results`), run via a new `run-tests.sh`.

## Global Constraints

- **Plugin:** `architect-critic` only (Phase A). Version bump `0.2.2 → 0.3.0` in **both** `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` (dual-publish parity — `tests/test-codex-dual-publish.sh` from repo root).
- **Sync path is sacred:** do not modify `ac_codex_run_audit`, `_ac_codex_run_with_timeout`, `_ac_codex_schema_path`, or the existing `tests/unit/test-codex.sh` behavior. Async is **additive**.
- **`set -e` discipline:** every helper runs through `bin/arc` (`set -euo pipefail`). `ac_codex_wait` MUST always return rc=0 (non-throwing) — the highest-risk surface; port intact.
- **Dispatcher form in skill prose:** call `arc codex_<verb>` / `arc state_<verb>` — never bare `ac_codex_*` (a fresh skill shell sources no libs; only `bin/arc` does).
- **No silent fallback:** `--async` with Codex unready → hard-fail with remediation (the user chose async; the *sync* `/critique --close` is the explicit foreground option). The doctor is the **only** fail-soft surface.
- **Companion env override:** `ARCHITECT_CRITIC_CODEX_COMPANION` (tests point this at the shim; no real Codex, no network).
- **Naming:** new skills are gerund-named (`checking-adversary-readiness`, `managing-async-critique`). Return contract embedded in the prompt-file is `{challenges[], gaps[]}` (the companion never sees the system prompt).
- **Portability:** BSD/GNU-safe (`stat`, `date`, `mktemp`; no bare `$TMPDIR`); pre-scan before pushing. CI is Linux (ubuntu-latest).
- **Spec:** `docs/agent-driven-program/specs/2026-06-18-architect-critic-async-adversary.md` is the source of truth (§ refs below point into it).

---

## File Structure

**Create:**
- `architect-critic/run-tests.sh` — suite runner (globs `tests/unit/test-*.sh tests/integration/test-*.sh`). *Closes the CI gap.*
- `architect-critic/tests/fixtures/codex-shim/codex-companion.mjs` — env-driven fake companion (ported).
- `architect-critic/tests/unit/test-codex-async.sh` — async spine tests.
- `architect-critic/tests/unit/test-state-external-runs.sh` — `external_runs[]` CRUD + v2→v3 migration tests.
- `architect-critic/tests/unit/test-doctor.sh` — readiness probe tests.
- `architect-critic/skills/checking-adversary-readiness/SKILL.md` + `architect-critic/commands/critique-doctor.md`.
- `architect-critic/skills/managing-async-critique/SKILL.md` + `architect-critic/commands/critique-jobs.md`.

**Modify:**
- `architect-critic/lib/codex.sh` — add async section (keep sync path).
- `architect-critic/lib/state.sh` — `external_runs[]` CRUD.
- `architect-critic/lib/migration.sh` — v2→v3 step.
- `architect-critic/skills/critiquing-spec/SKILL.md` — `--async` dispatch branch + size hint + persist host self-audit; factor Steps 7–9 into a labelled shared "Consolidate + Rebuttal + Append" procedure.
- `architect-critic/skills/reviewing-critique-history/SKILL.md` — list in-flight `external_runs`.
- `architect-critic/hooks-handlers/session-start.sh` — read-only in-flight count.
- `architect-critic/.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` — v0.3.0.
- `architect-critic/CHANGELOG.md`, `README.md` — v0.3.0 entry + version table.
- `.github/workflows/tests.yml` — add the architect-critic suite step.

**Reuse (read, do not reinvent):**
- `scaffold-onboard/lib/codex.sh` — spine source (port `resolve_companion`/`target_root`/`preflight`/`dispatch`/`wait`/`result`/`_cancel`/`_version_gt`/`_mtime`).
- `scaffold-onboard/tests/codex-shim/codex-companion.mjs` — shim source.
- `architect-critic/lib/consolidator.sh` — cross-confirmation merge (unchanged; consumed by resume).

---

## Task 0: Test runner + CI wiring

**Files:**
- Create: `architect-critic/run-tests.sh`
- Modify: `.github/workflows/tests.yml`

**Interfaces:**
- Produces: `bash architect-critic/run-tests.sh [file...]` — runs all `tests/unit/test-*.sh` + `tests/integration/test-*.sh`, exits non-zero if any file fails. Every later task verifies with this.

- [ ] **Step 1: Write the runner** (mirrors `scaffold-onboard/run-tests.sh`, adapted for the `unit/`+`integration/` layout)

```bash
#!/usr/bin/env bash
# run-tests.sh — architect-critic test runner.
# Discovers tests/unit/test-*.sh + tests/integration/test-*.sh (or runs files passed as args).
# Aggregates per-file results. Exits non-zero if any file fails.
set -uo pipefail
PLUGIN_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PLUGIN_ROOT" || { echo "run-tests.sh: cannot cd to $PLUGIN_ROOT" >&2; exit 1; }
FILES=0
FAILED_FILES=()
if [[ $# -gt 0 ]]; then
  TARGETS=("$@")
else
  TARGETS=(tests/unit/test-*.sh tests/integration/test-*.sh)
fi
for t in "${TARGETS[@]}"; do
  [[ -f "$t" ]] || continue
  FILES=$((FILES + 1))
  echo "=== $t ==="
  if bash "$t"; then :; else FAILED_FILES+=("$t"); fi
  echo ""
done
echo "================================================================"
echo "Test files run: $FILES"
echo "Failed files:   ${#FAILED_FILES[@]}"
if [[ "${#FAILED_FILES[@]}" -gt 0 ]]; then
  printf '  - %s\n' "${FAILED_FILES[@]}"
  exit 1
fi
exit 0
```

- [ ] **Step 2: Make it executable and run the existing suite (must be green before any new work)**

Run: `chmod +x architect-critic/run-tests.sh && bash architect-critic/run-tests.sh`
Expected: PASS — every existing unit + integration file runs, `Failed files: 0`. (If any pre-existing failure, STOP and surface it — do not build on red.)

- [ ] **Step 3: Wire architect-critic into CI**

In `.github/workflows/tests.yml`, after the `scaffold-onboard suite` step add:

```yaml
      - name: architect-critic suite
        run: bash architect-critic/run-tests.sh
```

- [ ] **Step 4: Commit**

```bash
git add architect-critic/run-tests.sh .github/workflows/tests.yml
git commit -m "test(architect-critic): add run-tests.sh runner + wire into CI"
```

---

## Task 1: Companion test shim + async test skeleton

**Files:**
- Create: `architect-critic/tests/fixtures/codex-shim/codex-companion.mjs`
- Create: `architect-critic/tests/unit/test-codex-async.sh`
- Modify: `architect-critic/tests/_helpers.sh` (add `setup_codex_companion_shim`)

**Interfaces:**
- Produces: env-driven fake companion supporting `setup|task|status|result|cancel --json`, controlled by `CODEX_SHIM_*` env vars; `setup_codex_companion_shim` helper that exports `ARCHITECT_CRITIC_CODEX_COMPANION` to the shim path.

- [ ] **Step 1: Port the shim** — copy `scaffold-onboard/tests/codex-shim/codex-companion.mjs` to `architect-critic/tests/fixtures/codex-shim/codex-companion.mjs` verbatim, then change the **default** `CODEX_SHIM_RESULT_RAWOUTPUT` to an architect-critic-shaped block:

````
```json
{"challenges":[{"text":"Codex challenge A","severity":"high","rationale":"why"}],"gaps":[]}
```
````
Keep all env knobs: `CODEX_SHIM_LOG`, `CODEX_SHIM_JOBID`, `CODEX_SHIM_STATUS`, `CODEX_SHIM_RESULT_RAWOUTPUT`, `CODEX_SHIM_FAIL`, `CODEX_SHIM_NO_JOBID`. (Read the source first; the five subcommands and env contract are documented in its header.)

- [ ] **Step 2: Add the helper to `tests/_helpers.sh`**

```bash
setup_codex_companion_shim() {
  local shim_dir
  shim_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/fixtures/codex-shim" && pwd)"
  export ARCHITECT_CRITIC_CODEX_COMPANION="$shim_dir/codex-companion.mjs"
}
```

- [ ] **Step 3: Write the async test skeleton** (`tests/unit/test-codex-async.sh`)

```bash
#!/usr/bin/env bash
# test-codex-async.sh — async codex spine (companion task --background) for v0.3.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$TESTS_DIR/_helpers.sh"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
ARC="$PLUGIN_ROOT/bin/arc"
echo "=== test-codex-async.sh (v0.3) ==="

# guard: node required
if ! command -v node >/dev/null 2>&1; then
  echo "  ! node not found — skipping async codex tests (loud skip)"; exit 0
fi

# placeholder assertion so the file is a valid, discoverable suite from day one
assert_eq "shim resolves" "ok" "ok"
report_results
```

- [ ] **Step 4: Run it (must pass as a trivial green skeleton)**

Run: `bash architect-critic/run-tests.sh tests/unit/test-codex-async.sh`
Expected: PASS (1 passed). Confirms discovery + helper wiring before real tests land.

- [ ] **Step 5: Commit**

```bash
git add architect-critic/tests/fixtures/codex-shim/codex-companion.mjs architect-critic/tests/unit/test-codex-async.sh architect-critic/tests/_helpers.sh
git commit -m "test(architect-critic): port codex-companion shim + async test skeleton"
```

---

## Task 2: Async spine in `lib/codex.sh`

**Files:**
- Modify: `architect-critic/lib/codex.sh` (append async section; keep sync path)
- Modify: `architect-critic/tests/unit/test-codex-async.sh`

**Interfaces:**
- Consumes: `ARCHITECT_CRITIC_CODEX_COMPANION`, the shim (Task 1).
- Produces:
  - `ac_codex_resolve_companion` → echoes companion path (rc0); rc1 + remediation if absent.
  - `ac_codex_target_root <artifact-path>` → echoes the git-toplevel (or nearest existing ancestor) containing the artifact.
  - `ac_codex_preflight <target-root>` → rc0 ready; rc1 + remediation string (uninstalled / `codex login` / untrusted).
  - `ac_codex_dispatch <target-root> <prompt-file>` → echoes job-id (rc0); rc1 on launch failure.
  - `ac_codex_wait <target-root> <job-id> [--poll N --stall N --cap N]` → echoes one of `completed|failed|cancelled|stalled|capped|error`; **always rc0**.
  - `ac_codex_result <target-root> <job-id>` → echoes the last fenced JSON block (rc0); rc1 if none / not an object with `.challenges`.
  - internal: `_ac_codex_cancel`, `_ac_codex_version_gt`, `_ac_codex_mtime`.
  - `_ac_codex_validate_json` extended: `.challenges` is a required array; `.gaps` optional array.

- [ ] **Step 1: Write failing tests** — append to `tests/unit/test-codex-async.sh` (replace the placeholder assertion):

```bash
ROOT="$(setup_tmp_repo)"; setup_codex_companion_shim

# resolve: override honored
echo "-- resolve --"
got="$(bash "$ARC" codex_resolve_companion 2>/dev/null)"; assert_eq "resolve returns override path" "$ARCHITECT_CRITIC_CODEX_COMPANION" "$got"

# preflight: ready
echo "-- preflight --"
assert_exit_code 0 bash "$ARC" codex_preflight "$ROOT/repo"

# dispatch: job-id echoed
echo "-- dispatch --"
pf="$ROOT/prompt.md"; printf 'audit this\n' > "$pf"
export CODEX_SHIM_JOBID="job-xyz"
got="$(bash "$ARC" codex_dispatch "$ROOT/repo" "$pf" 2>/dev/null)"; assert_eq "dispatch echoes jobId" "job-xyz" "$got"

# wait: completed → rc0 + token; failed → rc0 (non-throwing)
echo "-- wait --"
export CODEX_SHIM_STATUS="completed"
got="$(bash "$ARC" codex_wait "$ROOT/repo" "job-xyz" --poll 0 2>/dev/null)"; assert_eq "wait completed" "completed" "$got"
export CODEX_SHIM_STATUS="failed"
got="$(bash "$ARC" codex_wait "$ROOT/repo" "job-xyz" --poll 0 2>/dev/null)"; assert_eq "wait failed token" "failed" "$got"
assert_exit_code 0 bash "$ARC" codex_wait "$ROOT/repo" "job-xyz" --poll 0   # non-throwing under set -e

# result: extracts the {challenges,gaps} block
echo "-- result --"
export CODEX_SHIM_STATUS="completed"
export CODEX_SHIM_RESULT_RAWOUTPUT='prose first
```json
{"challenges":[{"text":"X","severity":"high","rationale":"r"}],"gaps":[]}
```'
got="$(bash "$ARC" codex_result "$ROOT/repo" "job-xyz" 2>/dev/null | jq -r '.challenges[0].text')"
assert_eq "result extracts challenge" "X" "$got"

# result: no fence → rc1
export CODEX_SHIM_RESULT_RAWOUTPUT='no json here'
assert_exit_code 1 bash "$ARC" codex_result "$ROOT/repo" "job-xyz"

report_results
```

- [ ] **Step 2: Run to verify they fail**

Run: `bash architect-critic/run-tests.sh tests/unit/test-codex-async.sh`
Expected: FAIL — `arc: unknown function codex_resolve_companion` (exit 2) / assertion failures.

- [ ] **Step 3: Port the spine into `lib/codex.sh`** — at the END of the file (after the existing sync functions), add an async section. Port these functions from `scaffold-onboard/lib/codex.sh` with the transforms below. **Read the source file first**, then apply uniformly:
  - Rename prefix `sf_` → `ac_`, `_sf_` → `_ac_`.
  - Keep verbatim: `_ac_codex_version_gt`, `_ac_codex_mtime`, `ac_codex_resolve_companion` (swap env var to `ARCHITECT_CRITIC_CODEX_COMPANION`; keep the cache/marketplace glob + version-aware newest pick), `ac_codex_target_root`, `ac_codex_preflight` (companion `setup --json` parse + path-prefix trust), `ac_codex_wait` (poll/stall/cap, `done`→`completed`, **always rc0**), `ac_codex_result` (fence-parse last block), `_ac_codex_cancel`.
  - `ac_codex_dispatch`: keep the `task --background --prompt-file <abs> --json` launch + jobId extraction, but **drop `--write`** (read-only adversary; see §3.2 open item — if the shim/companion rejects no-`--write`, keep `--write`). Drop `--resume-last`/`--fresh` flags (not needed here).
  - **Drop entirely** (implementer/synthesizer-only): `verify_nocommit`, all worktree management, the `{mode,…}` synthesis return shape.
  - Extend the existing `_ac_codex_validate_json` (do NOT duplicate): accept stdin OR a file; require `.challenges` to be an array; `.gaps` optional array. The sync path already calls it — keep that call green.

- [ ] **Step 4: Run to verify they pass**

Run: `bash architect-critic/run-tests.sh tests/unit/test-codex-async.sh`
Expected: PASS (all async assertions). Then run the **full** suite: `bash architect-critic/run-tests.sh` — Expected: `Failed files: 0` (sync `test-codex.sh` still green — proves additive).

- [ ] **Step 5: Commit**

```bash
git add architect-critic/lib/codex.sh architect-critic/tests/unit/test-codex-async.sh
git commit -m "feat(architect-critic): async codex spine (companion task --background) [#39]"
```

---

## Task 3: `state.json` v3 — `external_runs[]` + migration

**Files:**
- Modify: `architect-critic/lib/state.sh`, `architect-critic/lib/migration.sh`
- Create: `architect-critic/tests/unit/test-state-external-runs.sh`

**Interfaces:**
- Consumes: existing `ac_state_path`, `ac_data_dir`, `ac_lock_acquire/release`, `ac_guarded_jq_write`.
- Produces:
  - `ac_state_external_run_add --run-id R --host H --adversary A --artifact P --depth D --result-path RP [--codex-session-id S]` → appends a `running` record (`started_at` = now UTC); rc0.
  - `ac_state_external_run_set_status <run-id> <status> [--completed-at TS]` → updates `status` (+ `completed_at` if terminal); rc0; rc1 if run-id absent.
  - `ac_state_external_run_get <run-id>` → echoes the record JSON; rc1 if absent.
  - `ac_state_external_run_list [--status S]` → echoes a JSON array (optionally filtered).
  - `ac_state_external_run_resolve <run-id> <request-id>` → sets `resolved_run_request_id` **once**; rc1 if already set (idempotency guard).
  - migration: a v2→v3 step adding empty `external_runs` + `schema_version=3`, idempotent, preserving all v2 fields (incl. no `in_flight`).

- [ ] **Step 1: Write failing tests** (`tests/unit/test-state-external-runs.sh`)

```bash
#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$TESTS_DIR/_helpers.sh"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
ARC="$PLUGIN_ROOT/bin/arc"
echo "=== test-state-external-runs.sh ==="
ROOT="$(setup_tmp_repo)"

# add + get
bash "$ARC" state_external_run_add --run-id r1 --host claude --adversary codex \
  --artifact /tmp/spec.md --depth close --result-path "$CLAUDE_PLUGIN_DATA/async/r1/result.json"
got="$(bash "$ARC" state_external_run_get r1 | jq -r '.status')"
assert_eq "added run is running" "running" "$got"

# set_status terminal
bash "$ARC" state_external_run_set_status r1 completed --completed-at 2026-06-18T00:00:00Z
got="$(bash "$ARC" state_external_run_get r1 | jq -r '.status')"
assert_eq "status updated" "completed" "$got"

# list filter
got="$(bash "$ARC" state_external_run_list --status completed | jq 'length')"
assert_eq "one completed" "1" "$got"

# resolve once; second resolve fails (idempotency guard)
assert_exit_code 0 bash "$ARC" state_external_run_resolve r1 req-1
assert_exit_code 1 bash "$ARC" state_external_run_resolve r1 req-2
got="$(bash "$ARC" state_external_run_get r1 | jq -r '.resolved_run_request_id')"
assert_eq "resolved id pinned" "req-1" "$got"

# migration v2 → v3 (idempotent, preserves recent_runs, no in_flight)
sf="$(bash "$ARC" state_path 2>/dev/null || echo "$CLAUDE_PLUGIN_DATA/state.json")"
printf '%s' '{"schema_version":2,"recent_runs":[{"request_id":"old"}],"principle_promotions":[],"candidate_promotions":[],"declined_candidates":[],"auto_promote_suppressions":[]}' > "$sf"
bash "$ARC" migrate_state
assert_eq "schema bumped" "3" "$(jq -r '.schema_version' "$sf")"
assert_eq "external_runs seeded" "0" "$(jq -r '.external_runs|length' "$sf")"
assert_eq "recent_runs preserved" "old" "$(jq -r '.recent_runs[0].request_id' "$sf")"
assert_eq "no in_flight" "null" "$(jq -r '.in_flight // "null"' "$sf")"
bash "$ARC" migrate_state   # idempotent
assert_eq "still v3" "3" "$(jq -r '.schema_version' "$sf")"
report_results
```

- [ ] **Step 2: Run to verify they fail**

Run: `bash architect-critic/run-tests.sh tests/unit/test-state-external-runs.sh`
Expected: FAIL — unknown functions / migration leaves `schema_version:2`.

- [ ] **Step 3: Implement** — add the CRUD to `lib/state.sh` following the existing `ac_state_append_run` pattern (lock-guarded `ac_guarded_jq_write`, ISO-8601 UTC `completed_at`, cap the array to the last 20 like `recent_runs`). `ac_state_external_run_resolve` reads the record; if `resolved_run_request_id` is non-null → `return 1`; else set it. Add the v2→v3 step in `lib/migration.sh` mirroring the existing v1→v2 (read `schema_version`; if `2`, `jq '.external_runs = (.external_runs // []) | .schema_version = 3'`; idempotent on `>=3`).

- [ ] **Step 4: Run to verify they pass + full suite**

Run: `bash architect-critic/run-tests.sh tests/unit/test-state-external-runs.sh && bash architect-critic/run-tests.sh`
Expected: PASS; `Failed files: 0` (existing `test-state.sh` + `test-migration.sh` still green).

- [ ] **Step 5: Commit**

```bash
git add architect-critic/lib/state.sh architect-critic/lib/migration.sh architect-critic/tests/unit/test-state-external-runs.sh
git commit -m "feat(architect-critic): state.json v3 external_runs[] + v2->v3 migration [#39]"
```

---

## Task 4: Readiness doctor

**Files:**
- Modify: `architect-critic/lib/codex.sh` (add `ac_codex_doctor`)
- Create: `architect-critic/tests/unit/test-doctor.sh`
- Create: `architect-critic/skills/checking-adversary-readiness/SKILL.md`, `architect-critic/commands/critique-doctor.md`

**Interfaces:**
- Consumes: `ac_codex_resolve_companion`, `ac_codex_preflight`, companion `setup --json`.
- Produces: `ac_codex_doctor` → prints a human-readable readiness report (one line per check: codex bin+version, claude bin+version, companion resolvable, auth via `setup --json`, async cap/poll/stall config); **always rc0** (fail-soft); each not-ready line carries a fix-it hint.

- [ ] **Step 1: Write failing tests** (`tests/unit/test-doctor.sh`)

```bash
#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$TESTS_DIR/_helpers.sh"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
ARC="$PLUGIN_ROOT/bin/arc"
echo "=== test-doctor.sh ==="
ROOT="$(setup_tmp_repo)"; setup_codex_companion_shim

# ready path
out="$(bash "$ARC" codex_doctor 2>&1)"
assert_exit_code 0 bash "$ARC" codex_doctor      # fail-soft
echo "$out" | grep -qi "companion" && { echo "  ✓ reports companion"; PASS=$((PASS+1)); } || { echo "  ✗ no companion line"; FAIL=$((FAIL+1)); }

# unauthed → still rc0, surfaces a login hint
export CODEX_SHIM_STATUS=""   # n/a here; drive auth via setup
# Simulate not-logged-in by pointing the override at a missing companion:
export ARCHITECT_CRITIC_CODEX_COMPANION="$ROOT/nope.mjs"
out="$(bash "$ARC" codex_doctor 2>&1)"
assert_exit_code 0 bash "$ARC" codex_doctor
echo "$out" | grep -qiE "not (found|resolvable)|install|login" && { echo "  ✓ surfaces remediation"; PASS=$((PASS+1)); } || { echo "  ✗ no remediation"; FAIL=$((FAIL+1)); }
report_results
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash architect-critic/run-tests.sh tests/unit/test-doctor.sh`
Expected: FAIL — `unknown function codex_doctor`.

- [ ] **Step 3: Implement `ac_codex_doctor`** in `lib/codex.sh` — probe each item, print `✓`/`✗ <reason> → <fix>`, never exit non-zero. Reuse `ac_codex_resolve_companion` (companion line) and the companion `setup --json` parse (auth/schema). Factor the `command -v codex/claude` + `--version` capture into a small `_ac_probe_bin <name>` helper and have **critiquing-spec Step 3 reference the same `arc` verb** (single source of truth — note this in Task 5).

- [ ] **Step 4: Write the doctor skill + command**

`skills/checking-adversary-readiness/SKILL.md` — gerund skill (frontmatter `name: checking-adversary-readiness`, a `description:` with trigger phrases "check adversary readiness", "is codex ready", "critique doctor"). Body: a 1–3 step procedure that runs `arc codex_doctor`, presents the report, and — only with explicit user approval — offers the install/login commands to run. Make clear it is advisory and never blocks.
`commands/critique-doctor.md` — thin wrapper invoking the skill (mirror `commands/critique.md` shape).

- [ ] **Step 5: Run doctor tests + full suite + dual-publish parity**

Run: `bash architect-critic/run-tests.sh tests/unit/test-doctor.sh && bash architect-critic/run-tests.sh && bash tests/test-codex-dual-publish.sh`
Expected: PASS; `Failed files: 0`; parity OK (new SKILL.md frontmatter valid on both surfaces).

- [ ] **Step 6: Commit**

```bash
git add architect-critic/lib/codex.sh architect-critic/tests/unit/test-doctor.sh architect-critic/skills/checking-adversary-readiness architect-critic/commands/critique-doctor.md
git commit -m "feat(architect-critic): readiness doctor skill + /critique-doctor [#39]"
```

---

## Task 5: `/critique --async` dispatch branch + size guidance

**Files:**
- Modify: `architect-critic/lib/codex.sh` (add `ac_codex_size_hint`)
- Modify: `architect-critic/skills/critiquing-spec/SKILL.md`
- Modify: `architect-critic/tests/unit/test-codex-async.sh` (size-hint test + seam-prose lints)

**Interfaces:**
- Consumes: `ac_codex_target_root/preflight/dispatch` (Task 2), `ac_state_external_run_add` (Task 3).
- Produces: `ac_codex_size_hint <artifact-path>` → echoes `foreground` or `background` (threshold `ARCHITECT_CRITIC_ASYNC_HINT_LINES`, default 400); rc0. SKILL.md gains a labelled **"Consolidate + Rebuttal + Append"** procedure (the current Steps 7–9) and an `--async` branch in Step 6.

- [ ] **Step 1: Write failing tests** (append to `test-codex-async.sh`)

```bash
echo "-- size hint --"
big="$ROOT/big.md"; for i in $(seq 1 500); do echo "line $i"; done > "$big"
small="$ROOT/small.md"; printf 'tiny\n' > "$small"
assert_eq "big → background" "background" "$(bash "$ARC" codex_size_hint "$big")"
assert_eq "small → foreground" "foreground" "$(bash "$ARC" codex_size_hint "$small")"

echo "-- seam-prose lints --"
SK="$PLUGIN_ROOT/skills/critiquing-spec/SKILL.md"
grep -q -- "--async" "$SK" && { echo "  ✓ --async branch documented"; PASS=$((PASS+1)); } || { echo "  ✗ no --async"; FAIL=$((FAIL+1)); }
grep -qi "Consolidate + Rebuttal + Append" "$SK" && { echo "  ✓ shared procedure labelled"; PASS=$((PASS+1)); } || { echo "  ✗ no shared-procedure label"; FAIL=$((FAIL+1)); }
grep -qi "no silent" "$SK" && { echo "  ✓ no-silent-fallback noted"; PASS=$((PASS+1)); } || { echo "  ✗ fallback rule missing"; FAIL=$((FAIL+1)); }
```
(Place these **before** the final `report_results` call.)

- [ ] **Step 2: Run to verify failures**

Run: `bash architect-critic/run-tests.sh tests/unit/test-codex-async.sh`
Expected: FAIL — `unknown function codex_size_hint`; grep lints fail.

- [ ] **Step 3: Implement `ac_codex_size_hint`** in `lib/codex.sh`:

```bash
ac_codex_size_hint() {
  local artifact="$1"
  local thresh="${ARCHITECT_CRITIC_ASYNC_HINT_LINES:-400}"
  local lines=0
  [[ -f "$artifact" ]] && lines="$(wc -l < "$artifact" | tr -d ' ')"
  if [[ "$lines" -ge "$thresh" ]]; then echo "background"; else echo "foreground"; fi
  return 0
}
```

- [ ] **Step 4: Edit `critiquing-spec/SKILL.md`** — (a) label the existing consolidate→rebuttal→append steps as the shared **"Consolidate + Rebuttal + Append"** procedure that takes `{claude_audit, codex_audit, artifact, depth}`; (b) in Step 6, add the `--async` branch in prose:

```
If `--async` AND close-depth AND host=Claude:
  1. Run the host self-audit; SHOW it as a read-only preview (do NOT enter the rebuttal).
  2. Persist it: write the challenge JSON to ${data_dir}/async/<run_id>/claude-audit.json.
  3. SIZE HINT: run `arc codex_size_hint "<artifact>"` and surface the recommendation.
  4. `arc codex_preflight "$(arc codex_target_root "<artifact>")"` — on rc≠0, HARD-FAIL
     with the remediation string (NO silent foreground fallback; tell the user `/critique --close`
     is the foreground option).
  5. Build the adversarial prompt; append the `## Return contract` ({challenges,gaps}) section to a
     prompt-file OUTSIDE any repo tree.
  6. job="$(arc codex_dispatch "$target_root" "$pf")"; rm -f "$pf".
  7. `arc state_external_run_add --run-id "$job" --host claude --adversary codex
      --artifact "<artifact>" --depth close --result-path ".../async/$job/result.json"`.
  8. Print the handle + "resume with `/critique-jobs resume $job`". STOP (do not consolidate now).
The synchronous close-depth path (no `--async`) is UNCHANGED.
```

- [ ] **Step 5: Run tests + full suite**

Run: `bash architect-critic/run-tests.sh tests/unit/test-codex-async.sh && bash architect-critic/run-tests.sh`
Expected: PASS; `Failed files: 0`.

- [ ] **Step 6: Commit**

```bash
git add architect-critic/lib/codex.sh architect-critic/skills/critiquing-spec/SKILL.md architect-critic/tests/unit/test-codex-async.sh
git commit -m "feat(architect-critic): /critique --async dispatch + size guidance [#39]"
```

---

## Task 6: Job-manager skill (status/result/cancel/resume) + history + session-start

**Files:**
- Create: `architect-critic/skills/managing-async-critique/SKILL.md`, `architect-critic/commands/critique-jobs.md`
- Modify: `architect-critic/skills/reviewing-critique-history/SKILL.md`, `architect-critic/hooks-handlers/session-start.sh`
- Modify: `architect-critic/tests/unit/test-state-external-runs.sh` (session-start count + history lint)

**Interfaces:**
- Consumes: `ac_codex_wait/result/_cancel` (Task 2), `ac_state_external_run_*` (Task 3), the shared "Consolidate + Rebuttal + Append" procedure (Task 5).
- Produces: `managing-async-critique` skill owning `status|result|cancel|resume`; `session-start.sh` prints an in-flight count.

- [ ] **Step 1: Write failing tests** (append to `test-state-external-runs.sh`, before `report_results`)

```bash
echo "-- session-start in-flight count --"
# fresh state with one running run
bash "$ARC" state_external_run_add --run-id r9 --host claude --adversary codex --artifact /tmp/s.md --depth close --result-path /tmp/r.json
out="$(CLAUDE_PLUGIN_DATA="$CLAUDE_PLUGIN_DATA" bash "$PLUGIN_ROOT/hooks-handlers/session-start.sh" 2>&1)"
echo "$out" | grep -qiE "in.?flight|background audit" && { echo "  ✓ hook surfaces in-flight"; PASS=$((PASS+1)); } || { echo "  ✗ hook silent on in-flight"; FAIL=$((FAIL+1)); }

echo "-- history lists external runs --"
grep -qi "external_run\|in-flight\|background" "$PLUGIN_ROOT/skills/reviewing-critique-history/SKILL.md" && { echo "  ✓ history mentions external runs"; PASS=$((PASS+1)); } || { echo "  ✗ history missing external runs"; FAIL=$((FAIL+1)); }
```

- [ ] **Step 2: Run to verify failures**

Run: `bash architect-critic/run-tests.sh tests/unit/test-state-external-runs.sh`
Expected: FAIL — hook silent; history lint fails.

- [ ] **Step 3: Write `managing-async-critique/SKILL.md`** — gerund frontmatter (`name: managing-async-critique`; description triggers: "critique jobs", "resume critique", "cancel critique audit", "/critique-jobs"). Body documents four verbs:
  - `status [id]` → `arc state_external_run_get` (+ optional live `arc codex_wait … --poll 0` once for a fresh token); print.
  - `result [id]` → `arc codex_result`; show raw challenges (no rebuttal).
  - `cancel [id]` → `arc codex_<cancel>` + `arc state_external_run_set_status <id> cancelled`.
  - `resume [id]` (default latest): read the run; **if `resolved_run_request_id` set → inspect-only** (print prior conclusion, append nothing); else require terminal `completed` (else report status, stop); load persisted `claude-audit.json` + `arc codex_result`; run `consolidator.sh` over both; enter the shared **Consolidate + Rebuttal + Append** procedure; on append, `arc state_external_run_resolve <id> <request_id>`.
  `commands/critique-jobs.md` — thin wrapper.

- [ ] **Step 4: Edit `reviewing-critique-history/SKILL.md`** — add a section that calls `arc state_external_run_list` and renders in-flight/terminal external runs alongside `recent_runs`.

- [ ] **Step 5: Edit `hooks-handlers/session-start.sh`** — after the principles line, add a read-only count (fail-open, exit 0):

```bash
# in-flight async audits (v0.3): read-only count, never fails the hook
RUNNING="$(bash "${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/bin/arc" state_external_run_list --status running 2>/dev/null | jq 'length' 2>/dev/null || echo 0)"
if [[ "${RUNNING:-0}" -gt 0 ]]; then
  echo "architect-critic: ${RUNNING} background audit(s) in flight — /critique-jobs to inspect"
fi
```

- [ ] **Step 6: Run tests + full suite + dual-publish parity**

Run: `bash architect-critic/run-tests.sh && bash tests/test-codex-dual-publish.sh`
Expected: `Failed files: 0`; parity OK.

- [ ] **Step 7: Commit**

```bash
git add architect-critic/skills/managing-async-critique architect-critic/commands/critique-jobs.md architect-critic/skills/reviewing-critique-history/SKILL.md architect-critic/hooks-handlers/session-start.sh architect-critic/tests/unit/test-state-external-runs.sh
git commit -m "feat(architect-critic): job-manager skill (status/result/cancel/resume) + in-flight surfacing [#39]"
```

---

## Task 7: Packaging + release (architect-critic v0.3.0)

**Files:**
- Modify: `architect-critic/.claude-plugin/plugin.json`, `architect-critic/.codex-plugin/plugin.json`, `architect-critic/CHANGELOG.md`, `architect-critic/README.md`, `docs/agent-driven-program/SPEC-agent-driven-program.md`

- [ ] **Step 1: Bump both plugin manifests** `0.2.2 → 0.3.0` (and update the `description` to mention async close-depth + doctor + job lifecycle). Keep them byte-identical where the dual-publish test requires.

- [ ] **Step 2: CHANGELOG v0.3.0** — Added: async close-depth adversary (dispatch/status/result/cancel), readiness doctor, durable `external_runs[]` (state v3), defer-to-resume unified rebuttal, size guidance. Note the **dual-publish constraint** (async = Claude-host→Codex-adversary only) and the **state v3 migration**.

- [ ] **Step 3: README version table** — architect-critic → 0.3.0; add the two new skills + `/critique-doctor`, `/critique-jobs` commands.

- [ ] **Step 4: Update `SPEC-agent-driven-program.md` §5/§6** — mark #39 Phase A shipped in SS-6; note Phase B (scaffold-dev gate) pending.

- [ ] **Step 5: Verify everything green**

Run: `bash architect-critic/run-tests.sh && bash tests/test-codex-dual-publish.sh`
Expected: `Failed files: 0`; parity OK.

- [ ] **Step 6: Portability pre-scan** (before pushing — CI is Linux)

Run: `grep -rnE 'stat -f|stat -c|[^A-Za-z_]TMPDIR[^A-Za-z_=]|date -r|mktemp [^-]' architect-critic/lib architect-critic/tests architect-critic/run-tests.sh || echo "clean"`
Expected: review each hit; ensure BSD/GNU-safe forms (the ported spine already handles `stat` both ways).

- [ ] **Step 7: Commit + push + open PR**

```bash
git add architect-critic/.claude-plugin/plugin.json architect-critic/.codex-plugin/plugin.json architect-critic/CHANGELOG.md architect-critic/README.md docs/agent-driven-program/SPEC-agent-driven-program.md
git commit -m "release(architect-critic): v0.3.0 — async external adversary + readiness doctor [#39 Phase A]"
git push -u origin feat/39-architect-critic-async-adversary
gh pr create --fill --base main
```

- [ ] **Step 8: Bot-review convergence** — address Codex + CodeRabbit + Devin findings; merge on clean verdicts + green CI + 0 unresolved threads (`feedback_bot_review_convergence_judgment`). After merge: `git tag architect-critic-v0.3.0 <merge-sha> && git push origin architect-critic-v0.3.0`; close #39 Phase A (note Phase B remains).

---

## Post-Phase-A (separate plan)

Phase B (scaffold-dev review gate, #6) ships as `scaffold-dev` v0.8.0 in its own plan after Phase A merges — it consumes this async API (spec §4, build waves B-W1…B-W3). Then run the **operator real-Codex smoke** (spec §6) manually.

## Self-Review

- **Spec coverage:** doctor (§3.1)→T4; async spine (§3.2/3.3)→T2; state v3 (§3.4)→T3; resume (§3.5)→T6; size-guidance (§3.6)→T5; surfaces (§3.7)→T4/T5/T6; dual-publish (§3.8)→parity checks in T4/T6/T7; state-coupling (§3.9)→ported spine T2; packaging (§9)→T7. CI/runner gap→T0. Phase B (§4) explicitly deferred to its own plan. **No gaps.**
- **Placeholders:** none — port instructions name the exact source file + transforms; new code is shown verbatim.
- **Type consistency:** function names (`ac_codex_resolve_companion/target_root/preflight/dispatch/wait/result/size_hint/doctor`, `ac_state_external_run_add/set_status/get/list/resolve`) are used identically across producing/consuming tasks; `external_runs[]` field names match §3.4.
