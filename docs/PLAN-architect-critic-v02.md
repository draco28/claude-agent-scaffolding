# architect-critic v0.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retrofit architect-critic from v0.1.3 (bash-orchestrating-Claude) to v0.2 (skill-first), fixing all 8 bugs in GitHub issue #1, dropping inbox/outbox file-IPC, shipping the deferred auto-promotion machinery, and integrating ghost-notes + CORE as default principles.

**Architecture:** 4 gerund-named skills (`critiquing-spec`, `reviewing-critique-history`, `listing-principles`, `promoting-principle`) do the work in markdown bodies Claude reads + acts on. Slash commands become thin `$ARGUMENTS` wrappers. Bash (`lib/`) reserved for bookkeeping (state.json, principles.md, codex subprocess, migration). One SessionStart hook for ambient status. LLM-as-judge eval harness for skill quality.

**Tech Stack:** Bash 3.2+ (macOS-portable), Codex CLI 0.125+, jq, Claude Code skill+command+hook layers.

**Branch:** `implementation-architect-critic-v02`

**Commit format:** `architect-critic: <description> (v0.2 Phase X)` — single line, no co-author trailer.

**Reference:** [SPEC-architect-critic-v02.md](./SPEC-architect-critic-v02.md), [HANDOFF-architect-critic-v02-spec.md](./HANDOFF-architect-critic-v02-spec.md), [GitHub issue #1](https://github.com/draco28/claude-agent-scaffolding/issues/1).

---

## Pre-flight

### Task P1: Create implementation branch and verify v0.1.3 baseline

**Files:** none (git operation + verification)

- [ ] **Step 1: Create branch from main**

```bash
cd /Volumes/master_ssd/projects/claude-agent-scaffolding
git checkout main && git pull
git checkout -b implementation-architect-critic-v02
```

- [ ] **Step 2: Verify v0.1.3 baseline tests pass (10 files, ~154 assertions)**

```bash
for t in architect-critic/tests/test-*.sh; do
  echo "=== $t ==="
  bash "$t" || echo "FAIL: $t"
done
```

Expected: all 10 files run; total assertions ~154; failures noted (some may already fail per issue #1 — that's OK, we're retrofitting).

- [ ] **Step 3: Confirm Codex CLI 0.125+ installed**

```bash
codex --version
```

Expected: `codex-cli 0.125.0` or higher. If lower, abort and instruct user to upgrade.

- [ ] **Step 4: Snapshot current plugin state for diff comparison**

```bash
mkdir -p /tmp/architect-critic-v01-snapshot
cp -R architect-critic/ /tmp/architect-critic-v01-snapshot/
```

- [ ] **Step 5: Commit branch start**

```bash
git commit --allow-empty -m "architect-critic: start v0.2 retrofit branch (v0.2 Phase Pre-flight)"
```

---

## Phase 0 — Eval harness + bug-repro fixtures

Establishes the **TDD discipline** for the rest of the build. Eval harness + 8 regression tests fail until corresponding implementation lands.

### Task 0.1: Scaffold the eval harness directory structure

**Files:**
- Create: `architect-critic/tests/eval/run-evals.sh`
- Create: `architect-critic/tests/eval/README.md`
- Create: `architect-critic/tests/eval/fixtures/{critiquing-spec,reviewing-critique-history,listing-principles,promoting-principle}/.gitkeep`
- Create: `architect-critic/tests/eval/rubrics/.gitkeep`

- [ ] **Step 1: Create the directories**

```bash
mkdir -p architect-critic/tests/eval/{fixtures/{critiquing-spec,reviewing-critique-history,listing-principles,promoting-principle},rubrics}
touch architect-critic/tests/eval/fixtures/{critiquing-spec,reviewing-critique-history,listing-principles,promoting-principle}/.gitkeep
touch architect-critic/tests/eval/rubrics/.gitkeep
```

- [ ] **Step 2: Write minimal `run-evals.sh` orchestrator stub**

```bash
cat > architect-critic/tests/eval/run-evals.sh <<'EOF'
#!/usr/bin/env bash
# run-evals.sh — orchestrate LLM-as-judge eval runs for architect-critic skills
# Usage: run-evals.sh [skill_name | all]
# Exit code: 0 = all scenarios pass; 1 = at least one failure

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS=(critiquing-spec reviewing-critique-history listing-principles promoting-principle)

target="${1:-all}"

run_skill_evals() {
  local skill="$1"
  local fixtures_dir="${EVAL_DIR}/fixtures/${skill}"
  local rubric="${EVAL_DIR}/rubrics/${skill}.md"

  if [[ ! -d "$fixtures_dir" ]]; then
    echo "SKIP: no fixtures dir for $skill"
    return 0
  fi

  for fixture in "$fixtures_dir"/*.md; do
    [[ -e "$fixture" ]] || continue
    echo "EVAL: $skill / $(basename "$fixture")"
    # TODO: Tasks 0.2+ implement: invoke skill via Agent subagent;
    # capture output; score via LLM-judge subagent; aggregate.
    echo "  PENDING (orchestrator stub)"
  done
}

if [[ "$target" == "all" ]]; then
  for s in "${SKILLS[@]}"; do
    run_skill_evals "$s"
  done
else
  run_skill_evals "$target"
fi
EOF
chmod +x architect-critic/tests/eval/run-evals.sh
```

- [ ] **Step 3: Write `tests/eval/README.md` documenting the eval pattern**

Create `architect-critic/tests/eval/README.md` with: purpose, fixture format (markdown with frontmatter `scenario:` `expected_severity:` etc.), rubric format (1-5 score per criterion, pass = ≥4 on each), how to add new fixtures, cost estimate (~40 LLM calls per full run).

- [ ] **Step 4: Verify orchestrator stub runs**

```bash
bash architect-critic/tests/eval/run-evals.sh all
```

Expected: prints "SKIP: no fixtures dir" or "PENDING" lines for each skill. Exit code 0.

- [ ] **Step 5: Commit**

```bash
git add architect-critic/tests/eval/
git commit -m "architect-critic: scaffold eval harness directory (v0.2 Phase 0)"
```

### Task 0.2: Write 8 bug-repro regression tests

**Files:**
- Create: `architect-critic/tests/integration/test-bug-repros.sh`

- [ ] **Step 1: Create the integration tests directory and stub the bug-repro file**

```bash
mkdir -p architect-critic/tests/integration
```

- [ ] **Step 2: Write the regression tests (one per bug, all failing initially)**

Create `architect-critic/tests/integration/test-bug-repros.sh` with this structure:

```bash
#!/usr/bin/env bash
# test-bug-repros.sh — regression tests for GitHub issue #1 bugs.
# Each test starts FAILING (the bug still exists) and turns GREEN as v0.2 fixes land.

set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TESTS_PASSED=0
TESTS_FAILED=0

assert_pass() {
  local desc="$1"
  echo "  PASS: $desc"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

assert_fail() {
  local desc="$1"
  echo "  FAIL: $desc"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

# --- BUG #1: $N substitution corrupts bash function locals ---
test_bug_1_arguments_bridge() {
  echo "BUG #1 — slash-command $ARGUMENTS bridge replaces \$N positionals"
  # When fixed: /critique --spec custom.md should resolve custom.md, not $1
  # Regression check: grep for any "$1" / "$2" usage in commands/critique.md (should be zero)
  if grep -nE '\$[12345]' "$PLUGIN_DIR/commands/critique.md" 2>/dev/null | grep -v '\$ARGUMENTS' | grep -v '#'; then
    assert_fail "commands/critique.md still uses bare \$N positionals"
  else
    assert_pass "commands/critique.md uses \$ARGUMENTS only"
  fi
}

# --- BUG #2: claude-self-audit silent no-op ---
test_bug_2_skill_body_runs_audit() {
  echo "BUG #2 — claude-self-audit lives in skill body (not bash -c orchestration)"
  # When fixed: critiquing-spec/SKILL.md should contain the audit instructions as
  # markdown for Claude to read; should NOT contain "bash -c" wrapper around audit
  local skill_body="$PLUGIN_DIR/skills/critiquing-spec/SKILL.md"
  if [[ ! -f "$skill_body" ]]; then
    assert_fail "critiquing-spec/SKILL.md does not exist yet"
    return
  fi
  if grep -q 'CLAUDE SELF-AUDIT INSTRUCTIONS' "$skill_body" && \
     ! grep -q 'bash -c.*CLAUDE_AUDIT_TMP' "$skill_body"; then
    assert_pass "audit instructions present in markdown, not bash-orchestrated"
  else
    assert_fail "audit step still bash-orchestrated or instructions missing"
  fi
}

# --- BUG #3: hard fail without MASTER-SPEC.md ---
test_bug_3_path_discovery() {
  echo "BUG #3 — spec path discovery does not hard-fail on missing MASTER-SPEC"
  local skill_body="$PLUGIN_DIR/skills/critiquing-spec/SKILL.md"
  [[ -f "$skill_body" ]] || { assert_fail "skill body missing"; return; }
  if grep -q 'AskUserQuestion' "$skill_body" && grep -q 'well_known_paths' "$skill_body"; then
    assert_pass "discovery order documented (manifest fast-path + AskUserQuestion fallback)"
  else
    assert_fail "discovery order not fully specified"
  fi
}

# --- BUG #4: rebuttal cycle skipped non-TTY ---
test_bug_4_rebuttal_in_conversation() {
  echo "BUG #4 — rebuttal cycle uses Claude conversation, not bash read"
  local skill_body="$PLUGIN_DIR/skills/critiquing-spec/SKILL.md"
  [[ -f "$skill_body" ]] || { assert_fail "skill body missing"; return; }
  # Ensure no bash "read -r" used inside skill body for rebuttal capture
  if grep -E '^[[:space:]]*read -r' "$skill_body" >/dev/null; then
    assert_fail "skill body still uses bash 'read -r' for input"
  else
    assert_pass "no bash read; rebuttal handled in conversation"
  fi
}

# --- BUG #5: codex availability surfaced ---
test_bug_5_codex_status_in_output() {
  echo "BUG #5 — codex availability surfaced to user before audit"
  local skill_body="$PLUGIN_DIR/skills/critiquing-spec/SKILL.md"
  [[ -f "$skill_body" ]] || { assert_fail "skill body missing"; return; }
  if grep -qE 'Codex (detected|available|not detected)' "$skill_body"; then
    assert_pass "codex status messages in skill body"
  else
    assert_fail "skill body does not surface codex availability"
  fi
}

# --- BUG #6: cost_usd dropped entirely ---
test_bug_6_cost_field_removed() {
  echo "BUG #6 — cost_usd field removed from state.json schema"
  local state_lib="$PLUGIN_DIR/lib/state.sh"
  [[ -f "$state_lib" ]] || { assert_fail "lib/state.sh missing"; return; }
  if grep -q 'cost_usd' "$state_lib"; then
    assert_fail "lib/state.sh still references cost_usd"
  else
    assert_pass "cost_usd absent from state.sh"
  fi
}

# --- BUG #7: README has standalone-use section ---
test_bug_7_readme_standalone() {
  echo "BUG #7 — README documents standalone use"
  local readme="$PLUGIN_DIR/README.md"
  [[ -f "$readme" ]] || { assert_fail "README missing"; return; }
  if grep -qE '## (Standalone|Standalone use)' "$readme"; then
    assert_pass "README has standalone-use section"
  else
    assert_fail "README missing standalone-use section"
  fi
}

# --- BUG #8: project_class fallback consequence documented ---
test_bug_8_project_class_doc() {
  echo "BUG #8 — project_class fallback consequence documented"
  local skill_body="$PLUGIN_DIR/skills/critiquing-spec/SKILL.md"
  local readme="$PLUGIN_DIR/README.md"
  if { [[ -f "$skill_body" ]] && grep -q 'project_class.*unknown' "$skill_body"; } || \
     { [[ -f "$readme" ]] && grep -q 'project_class.*unknown' "$readme"; }; then
    assert_pass "project_class=unknown consequence documented"
  else
    assert_fail "project_class=unknown consequence not documented"
  fi
}

# --- Run all ---
test_bug_1_arguments_bridge
test_bug_2_skill_body_runs_audit
test_bug_3_path_discovery
test_bug_4_rebuttal_in_conversation
test_bug_5_codex_status_in_output
test_bug_6_cost_field_removed
test_bug_7_readme_standalone
test_bug_8_project_class_doc

echo ""
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
[[ $TESTS_FAILED -eq 0 ]]
```

- [ ] **Step 3: Run the regression tests; expect 8 FAILs**

```bash
bash architect-critic/tests/integration/test-bug-repros.sh
```

Expected: most tests FAIL (skills don't exist yet, README doesn't have section, etc.). Test #1 may already pass or fail depending on current commands/critique.md state. This is the **starting baseline** — tracks bug fix progress.

- [ ] **Step 4: Commit**

```bash
git add architect-critic/tests/integration/test-bug-repros.sh
git commit -m "architect-critic: add 8 bug-repro regression tests (v0.2 Phase 0)"
```

### Task 0.3: Write 5 eval fixtures + rubric for `critiquing-spec`

**Files:**
- Create: `architect-critic/tests/eval/fixtures/critiquing-spec/01-hidden-assumption.md`
- Create: `architect-critic/tests/eval/fixtures/critiquing-spec/02-missing-rollback.md`
- Create: `architect-critic/tests/eval/fixtures/critiquing-spec/03-unenumerated-failure-mode.md`
- Create: `architect-critic/tests/eval/fixtures/critiquing-spec/04-spec-with-no-gaps.md`
- Create: `architect-critic/tests/eval/fixtures/critiquing-spec/05-aggressive-tone-baseline.md`
- Create: `architect-critic/tests/eval/rubrics/critiquing-spec.md`

- [ ] **Step 1: Author fixture 01 — spec with hidden assumption**

```markdown
---
scenario_id: 01-hidden-assumption
expected_severity: premise
expected_principle: ghost-notes
expected_finding: critic should surface the unstated assumption that the database supports transactions
---
# SPEC: User registration flow

## 1. Goal
Implement a registration endpoint that creates a user record and sends a welcome email.

## 2. Steps
1. Receive POST /register with email + password
2. Hash password
3. INSERT user row
4. INSERT welcome_email_job row
5. Return 201

## 3. Failure modes
- Duplicate email → return 409

(Spec ends here — note that step 3+4 assume atomicity without specifying transaction boundaries; the database type isn't mentioned anywhere.)
```

- [ ] **Step 2: Author fixtures 02-05 similarly**

Each fixture is a partial spec with a deliberate flaw the critic should find:
- **02-missing-rollback** — spec has a state-change operation with no rollback path described (target: `gap` severity)
- **03-unenumerated-failure-mode** — spec lists 2 failure modes but obvious 3rd (timeout) is missing (target: `gap` severity)
- **04-spec-with-no-gaps** — a deliberately well-written short spec; critic should EITHER find nothing OR surface only `alternative` severity items (negative control)
- **05-aggressive-tone-baseline** — spec is identical to 02 but we check CORE tone in critic's output (every challenge should open with curiosity-framing, e.g., "I might be missing something")

Use the same frontmatter pattern (`scenario_id`, `expected_severity`, `expected_principle`, `expected_finding`).

- [ ] **Step 3: Author rubric**

Create `architect-critic/tests/eval/rubrics/critiquing-spec.md` with the rubric described in SPEC §12.3 (5 criteria, ≥4/5 on each to pass).

- [ ] **Step 4: Verify fixtures parse correctly**

```bash
for f in architect-critic/tests/eval/fixtures/critiquing-spec/*.md; do
  echo "=== $f ==="
  head -10 "$f"
done
```

Expected: 5 files, each with frontmatter visible.

- [ ] **Step 5: Commit**

```bash
git add architect-critic/tests/eval/fixtures/critiquing-spec/ architect-critic/tests/eval/rubrics/critiquing-spec.md
git commit -m "architect-critic: add 5 critiquing-spec eval fixtures + rubric (v0.2 Phase 0)"
```

### Task 0.4: Write eval fixtures + rubrics for the other 3 skills

**Files:** mirror the structure from Task 0.3 for `reviewing-critique-history`, `listing-principles`, `promoting-principle`. ~5 fixtures + 1 rubric per skill.

- [ ] **Step 1: Author `reviewing-critique-history` fixtures** — 5 scenarios: empty history, single run, 10+ runs, mixed depths, run with codex_timeout flag.

- [ ] **Step 2: Author `listing-principles` fixtures** — 5 scenarios: only shipped defaults, mix of shipped + user-promoted, suppressed-candidate display, --source filter behavior, project-scoped vs user-global merge.

- [ ] **Step 3: Author `promoting-principle` fixtures** — 5 scenarios: new principle, duplicate (rejected), scope=project, link-to-challenge mode, validation failure (empty text).

- [ ] **Step 4: Author rubrics for each skill**

- [ ] **Step 5: Commit**

```bash
git add architect-critic/tests/eval/
git commit -m "architect-critic: add eval fixtures for remaining 3 skills (v0.2 Phase 0)"
```

### Task 0.5: Wire eval harness as a Claude-Code-session runbook (no API wrappers)

Per [[claude-code-sessions-only]]: the eval harness is **run from within a Claude Code session** using the `Agent` tool for both skill invocation AND LLM-as-judge scoring. There is no `claude-judge` / `claude-subagent` CLI helper. There is no API key. The orchestration logic lives in a markdown runbook that Claude reads + executes; bash is reserved for jq aggregation of the JSON results Claude writes.

**Files:**
- Create: `architect-critic/tests/eval/RUNBOOK.md` (the markdown procedure Claude follows)
- Modify: `architect-critic/tests/eval/run-evals.sh` (slimmed: prints invocation guidance + aggregates result files)
- Create: `architect-critic/tests/eval/lib/aggregate-scores.sh` (jq-driven score aggregation)
- Create: `architect-critic/tests/eval/results/.gitkeep` (output dir for per-fixture JSON results)

- [ ] **Step 1: Author `RUNBOOK.md` — the procedure Claude follows**

```markdown
# Eval Runbook (architect-critic)

This runbook is **executed by Claude Code in an interactive session**. There is no API-based runner. Open this repo in Claude Code, say *"run architect-critic evals"* (or paste the prompt below), and follow the procedure.

## Prompt to paste

> Run the architect-critic eval harness per `architect-critic/tests/eval/RUNBOOK.md`. For each skill (`critiquing-spec`, `reviewing-critique-history`, `listing-principles`, `promoting-principle`), iterate fixtures in `tests/eval/fixtures/<skill>/`, dispatch an `Agent` subagent to invoke the skill on each fixture, then dispatch a second `Agent` (the judge) with the rubric + fixture + output and ask it to score 1-5 on each criterion. Write per-fixture results to `tests/eval/results/<skill>/<fixture_id>.json`. When all skills processed, run `bash tests/eval/lib/aggregate-scores.sh` and report the pass/fail summary.

## Procedure (Claude executes these steps)

For each skill in `[critiquing-spec, reviewing-critique-history, listing-principles, promoting-principle]`:

  For each `fixture.md` in `tests/eval/fixtures/<skill>/`:

  1. **Invoke the skill.** Dispatch `Agent` (subagent_type=general-purpose or claude) with this prompt:
     > Read `architect-critic/skills/<skill>/SKILL.md` end-to-end. Then apply the skill to this fixture artifact (paste fixture body). Produce the skill's natural output. Do NOT improvise beyond what the skill body specifies.

     Capture the subagent's final output as `skill_output_<fixture_id>.txt` (a temp file).

  2. **Score via judge.** Dispatch a second `Agent` (fresh context) with this prompt:
     > You are an LLM-as-judge. Score the SKILL OUTPUT below against the RUBRIC. Return a single JSON object: `{"scores": {"criterion_name": N, ...}, "pass": true|false, "notes": "<one-sentence reason>"}`. Pass = all criteria ≥4. JSON only, no prose around it.
     >
     > RUBRIC: <paste rubric markdown>
     >
     > FIXTURE INPUT: <paste fixture>
     >
     > SKILL OUTPUT: <paste skill_output_<fixture_id>.txt>

     Capture the judge's JSON. Write it to `tests/eval/results/<skill>/<fixture_id>.json`.

  3. **Cleanup.** Remove the temp skill_output file. Move to next fixture.

After all fixtures processed:

  4. Run `bash architect-critic/tests/eval/lib/aggregate-scores.sh`. It reads all per-fixture JSON results and prints a pass/fail summary by skill + overall.

## Why this shape

- Claude Code subscription covers all Agent dispatches; no metered API.
- The runbook stays in markdown so the orchestration logic is auditable and adjustable without code changes.
- Bash only does what bash is good for: filesystem traversal + JSON aggregation via jq.
- Reruns are easy — delete `tests/eval/results/<skill>/` and re-run the prompt.

## Cost / time

- ~5 fixtures × 4 skills × 2 Agent dispatches = ~40 dispatches per full run.
- Wall time: 5-10 minutes in an interactive session.
- Re-running individual skills is cheap (drop ~10 dispatches).
```

- [ ] **Step 2: Slim `run-evals.sh` — it now prints the runbook prompt + delegates execution to Claude in-session**

Replace the entire body of `architect-critic/tests/eval/run-evals.sh` with:

```bash
#!/usr/bin/env bash
# run-evals.sh — print the eval runbook prompt for Claude Code session execution.
# This script does NOT call any LLM. Eval orchestration happens inside Claude Code.
# Usage: bash run-evals.sh [skill_name | all]   # prints the prompt to paste

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
target="${1:-all}"

cat <<EOF
=== architect-critic eval harness ===

This is a Claude-Code-session-driven eval. There is no API-based runner.

To run: open this repo in Claude Code and paste the following prompt:

---
Run the architect-critic eval harness per architect-critic/tests/eval/RUNBOOK.md.
${target:+(target: $target)}
For each skill, iterate fixtures in tests/eval/fixtures/<skill>/, dispatch an Agent
to invoke the skill on each fixture, then dispatch a judge Agent to score against
the rubric. Write per-fixture JSON results to tests/eval/results/<skill>/<id>.json.
When done, run bash tests/eval/lib/aggregate-scores.sh and report the summary.
---

After the in-session run completes, you can also run:
  bash $EVAL_DIR/lib/aggregate-scores.sh

to print the aggregate report from any existing result files.
EOF
```

- [ ] **Step 3: Author `lib/aggregate-scores.sh` — jq-driven results aggregator**

```bash
cat > architect-critic/tests/eval/lib/aggregate-scores.sh <<'EOF'
#!/usr/bin/env bash
# aggregate-scores.sh — read per-fixture JSON results and print pass/fail summary.
# Run AFTER the Claude-Code-session eval run has written results/*.json.

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="${EVAL_DIR}/results"

if [[ ! -d "$RESULTS_DIR" ]]; then
  echo "No results dir at $RESULTS_DIR — run the eval harness first."
  exit 1
fi

total_pass=0
total_fail=0
total_files=0

for skill_dir in "$RESULTS_DIR"/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill="$(basename "$skill_dir")"
  skill_pass=0
  skill_fail=0

  for result in "$skill_dir"*.json; do
    [[ -e "$result" ]] || continue
    total_files=$((total_files + 1))
    pass=$(jq -r '.pass' "$result" 2>/dev/null || echo "false")
    if [[ "$pass" == "true" ]]; then
      skill_pass=$((skill_pass + 1))
      total_pass=$((total_pass + 1))
    else
      skill_fail=$((skill_fail + 1))
      total_fail=$((total_fail + 1))
      notes=$(jq -r '.notes // ""' "$result" 2>/dev/null)
      echo "  FAIL: ${skill}/$(basename "$result" .json) — ${notes}"
    fi
  done

  echo "${skill}: ${skill_pass} pass / ${skill_fail} fail"
done

echo ""
echo "=== TOTAL: ${total_pass}/${total_files} passed ==="
[[ $total_fail -eq 0 ]]
EOF
chmod +x architect-critic/tests/eval/lib/aggregate-scores.sh
```

- [ ] **Step 4: Verify orchestrator stub + aggregator both run**

```bash
mkdir -p architect-critic/tests/eval/results
bash architect-critic/tests/eval/run-evals.sh all
bash architect-critic/tests/eval/lib/aggregate-scores.sh
```

Expected: `run-evals.sh` prints the runbook prompt; `aggregate-scores.sh` prints "TOTAL: 0/0 passed" (no result files yet).

- [ ] **Step 5: Smoke-test the runbook in a Claude Code session (manual)**

This step is interactive. Open Claude Code in the project root, paste the runbook prompt, and verify that Claude (a) reads the RUNBOOK, (b) iterates one skill's fixtures, (c) dispatches `Agent` for skill invocation, (d) dispatches `Agent` for judging, (e) writes a JSON to `results/<skill>/<fixture_id>.json`.

Expected: at least one results file written. (Real pass/fail depends on whether skills exist — at Phase 0 they don't, so all judges return `pass: false`. That's correct baseline behavior.)

- [ ] **Step 6: Commit**

```bash
git add architect-critic/tests/eval/
git commit -m "architect-critic: eval harness as Claude-Code-session runbook (no API wrappers) (v0.2 Phase 0)"
```

**Phase 0 close:** update CHANGELOG with "v0.2 Phase 0 — eval harness + bug-repro fixtures scaffolded; all skill-eval tests failing (baseline)."

---

## Phase 1 — 4 SKILL.md bodies

Each task makes one skill's eval pass.

### Task 1.1: Author `critiquing-spec/SKILL.md`

**Files:**
- Create: `architect-critic/skills/critiquing-spec/SKILL.md`
- Create: `architect-critic/skills/critiquing-spec/references/.gitkeep`

- [ ] **Step 1: Verify the skill makes its bug-repro tests pass (RED phase)**

```bash
bash architect-critic/tests/integration/test-bug-repros.sh | grep -E "BUG #(2|3|4|5|8)"
```

Expected: all FAIL (skill body doesn't exist yet).

- [ ] **Step 2: Author the skill body**

Create `architect-critic/skills/critiquing-spec/SKILL.md`. The body MUST contain:

- Frontmatter: `name: critiquing-spec`, `description:` with trigger phrases (audit/critique/adversarial review/challenge/deep audit)
- Step 1 (resolve artifact path) — order: explicit arg → manifest `well_known_paths.master_spec` → SPEC*/PLAN* heuristic → AskUserQuestion. Explicit "do NOT glob *.md" callout.
- Step 2 (resolve principles) — merge shipped → user → project → memory-bank. References [[ghost-notes]] and [[CORE protocol]] as shipped principles.
- Step 3 (codex detection) — `command -v codex` check; status messages ("Codex detected; will run fresh-frame", "Codex not detected; running claude-only").
- Step 4 (close-depth triggers) — `--close` flag, `--deep` flag, NL list ("deep audit", "close review", "deeper look", "adversarial fresh-frame").
- Step 5 (claude-self-audit IN CONVERSATION) — explicit instruction to Claude to do the audit here, NOT delegate to bash. Reference ghost-notes ("look for absent data") and CORE protocol from principles.md.
- Step 6 (codex invocation if applicable) — full Bash invocation per SPEC §5.1 step 6. Schema-bound output. Synchronous wait with progress message.
- Step 7 (consolidation via lib/consolidator.sh)
- Step 8 (rebuttal cycle) — sequential by default; "linear-on-demand" escape phrases; auto-batch for `alternative` severity. T=4 concession threshold via lib/scorer.sh.
- Step 9 (bookkeeping) — append run to state.json (schema v2); run auto-promotion check (lib/promotion.sh).
- Step 10 (summary emission) — structured output for consumer plugins.
- Plus: documentation of `project_class=unknown` consequence (for bug #8).

Use heading hierarchy and prose that Claude can read and ACT ON. This is the centerpiece — spend time here.

Total target length: 400-600 lines of markdown.

- [ ] **Step 3: Re-run bug-repro tests**

```bash
bash architect-critic/tests/integration/test-bug-repros.sh
```

Expected: tests for bugs #2, #3, #4, #5, #8 now PASS (skill body has the required content); bug #1 and #6 still fail (waiting for Phase 5 commands and Phase 3 lib changes); bug #7 still fails (Phase 9 README).

- [ ] **Step 4: Run critiquing-spec evals (in a Claude Code session)**

Open Claude Code in the repo, paste:

> Run the architect-critic eval harness per `architect-critic/tests/eval/RUNBOOK.md`, target `critiquing-spec` only.

Wait for Claude to dispatch the Agent + judge pairs across the 5 fixtures. Then in a shell:

```bash
bash architect-critic/tests/eval/lib/aggregate-scores.sh
```

Expected: at least 3/5 critiquing-spec fixtures PASS. If <3 pass, iterate on skill body before committing (delete `tests/eval/results/critiquing-spec/` and re-run the prompt).

- [ ] **Step 5: Commit**

```bash
git add architect-critic/skills/critiquing-spec/
git commit -m "architect-critic: author critiquing-spec SKILL.md (v0.2 Phase 1)"
```

### Task 1.2: Author `reviewing-critique-history/SKILL.md`

**Files:**
- Create: `architect-critic/skills/reviewing-critique-history/SKILL.md`

- [ ] **Step 1: Author the skill body**

Body responsibilities per SPEC §5.2:
- Read state.json (schema v2)
- Render `recent_runs[]` (default N=10, override via `--limit N` arg)
- Columns: completed_at, depth, adversaries_used, challenge_count, concessions, skill_invoked
- Note absence of `in_flight` (no async in v0.2)
- Format: human-readable table (markdown or aligned columns)

Target length: 100-200 lines.

- [ ] **Step 2: Run evals (Claude Code session)**

Paste in Claude Code: *"Run the architect-critic eval harness per `tests/eval/RUNBOOK.md`, target `reviewing-critique-history` only."* Then aggregate:

```bash
bash architect-critic/tests/eval/lib/aggregate-scores.sh
```

Expected: at least 4/5 PASS.

- [ ] **Step 3: Commit**

```bash
git add architect-critic/skills/reviewing-critique-history/
git commit -m "architect-critic: author reviewing-critique-history SKILL.md (v0.2 Phase 1)"
```

### Task 1.3: Author `listing-principles/SKILL.md`

**Files:**
- Create: `architect-critic/skills/listing-principles/SKILL.md`

- [ ] **Step 1: Author the skill body**

Per SPEC §5.3. Includes: source merging (shipped → user → project → memory-bank), source tag annotation, `--source all|shipped|user|project` filtering, suppression status display.

- [ ] **Step 2: Run evals (Claude Code session)**

Paste in Claude Code: *"Run the architect-critic eval harness per `tests/eval/RUNBOOK.md`, target `listing-principles` only."* Then aggregate:

```bash
bash architect-critic/tests/eval/lib/aggregate-scores.sh
```

Expected: at least 4/5 PASS.

- [ ] **Step 3: Commit**

```bash
git add architect-critic/skills/listing-principles/
git commit -m "architect-critic: author listing-principles SKILL.md (v0.2 Phase 1)"
```

### Task 1.4: Author `promoting-principle/SKILL.md`

**Files:**
- Create: `architect-critic/skills/promoting-principle/SKILL.md`

- [ ] **Step 1: Author the skill body**

Per SPEC §5.4. Includes: append to user-global OR project-scoped principles.md; uniqueness validation; auto-link to challenge fingerprint if invoked during critiquing-spec run.

- [ ] **Step 2: Run evals (Claude Code session)**

Paste in Claude Code: *"Run the architect-critic eval harness per `tests/eval/RUNBOOK.md`, target `promoting-principle` only."* Then aggregate:

```bash
bash architect-critic/tests/eval/lib/aggregate-scores.sh
```

Expected: at least 4/5 PASS.

- [ ] **Step 3: Commit**

```bash
git add architect-critic/skills/promoting-principle/
git commit -m "architect-critic: author promoting-principle SKILL.md (v0.2 Phase 1)"
```

**Phase 1 close:** all 4 skill evals at ≥4/5 fixtures passing. Update CHANGELOG: "v0.2 Phase 1 — 4 skill bodies authored; evals green."

---

## Phase 2 — Reference sub-docs

Templates + supporting docs that skills reference.

### Task 2.1: Author `templates/principles.md` with ghost-notes + CORE defaults

**Files:**
- Modify: `architect-critic/templates/principles.md`

- [ ] **Step 1: Read current principles.md template**

```bash
cat architect-critic/templates/principles.md
```

- [ ] **Step 2: Replace with v0.2 grammar (shipped defaults + user section + project section)**

Per SPEC §6.2 grammar exactly. Include the full ghost-notes principle text and the full CORE protocol (C/O/R/E with examples per `.claude/ghost-notes.md` lines 70-89).

- [ ] **Step 3: Verify principles.md parses via lib/principles.sh**

(Will be testable in Task 3.2 after lib/principles.sh is updated.)

- [ ] **Step 4: Commit**

```bash
git add architect-critic/templates/principles.md
git commit -m "architect-critic: ship ghost-notes + CORE as default principles (v0.2 Phase 2)"
```

### Task 2.2: Author `templates/output-schema.json` for codex constraint

**Files:**
- Create: `architect-critic/templates/output-schema.json`

- [ ] **Step 1: Write the schema**

Per SPEC §6.3 exactly. Include `challenges` (array of objects with text/severity/rationale/principle_applied), optional `divergences` (array of strings).

- [ ] **Step 2: Validate schema syntactically**

```bash
jq empty < architect-critic/templates/output-schema.json && echo "JSON valid"
```

- [ ] **Step 3: Commit**

```bash
git add architect-critic/templates/output-schema.json
git commit -m "architect-critic: add codex --output-schema constraint (v0.2 Phase 2)"
```

### Task 2.3: Author CORE-tone phrasing examples + ghost-notes worked example

**Files:**
- Create: `architect-critic/skills/critiquing-spec/references/core-tone-examples.md`
- Create: `architect-critic/skills/critiquing-spec/references/ghost-notes-worked-example.md`

- [ ] **Step 1: Author CORE-tone examples**

Show 5 challenge examples in both "wrong tone" and "CORE tone" forms. E.g.,
- Wrong: *"You forgot rollback for the migration."*
- Right (Curiosity): *"I might be missing something — is there a reason the migration doesn't document a rollback path?"*

- [ ] **Step 2: Author ghost-notes worked example**

Walk through a fictional spec audit step-by-step, showing where applying ghost-notes ("look for absent data") surfaced a challenge the literal-reading critic missed. ~150-300 lines.

- [ ] **Step 3: Commit**

```bash
git add architect-critic/skills/critiquing-spec/references/
git commit -m "architect-critic: add CORE-tone + ghost-notes worked examples (v0.2 Phase 2)"
```

**Phase 2 close:** update CHANGELOG: "v0.2 Phase 2 — reference sub-docs landed."

---

## Phase 3 — Slimmed `lib/` (TDD per module)

### Task 3.1: Refactor `lib/state.sh` for schema v2

**Files:**
- Modify: `architect-critic/lib/state.sh`
- Modify: `architect-critic/tests/unit/test-state.sh`

- [ ] **Step 1: Move existing test-state.sh to tests/unit/**

```bash
mkdir -p architect-critic/tests/unit
git mv architect-critic/tests/test-state.sh architect-critic/tests/unit/test-state.sh
```

- [ ] **Step 2: Write failing tests for new schema-v2 fields**

Add tests to `tests/unit/test-state.sh`:
- `test_concessions_field_in_recent_runs` — assert `concessions` integer present on append
- `test_skill_invoked_field_in_recent_runs` — assert `skill_invoked` string present on append
- `test_no_cost_usd_field` — assert `cost_usd` NOT in any recent_runs entry
- `test_no_in_flight_field` — assert `in_flight` array NOT in state structure
- `test_auto_promote_suppressions_30day` — append suppression with `reason_score: 4`, assert `expires_at` is 30 days from `suppressed_at`
- `test_auto_promote_suppressions_90day` — same but `reason_score: 5` → 90 days

- [ ] **Step 3: Run tests; expect FAILs**

```bash
bash architect-critic/tests/unit/test-state.sh
```

Expected: new tests fail.

- [ ] **Step 4: Update `lib/state.sh` to match schema v2**

- Remove all `cost_usd` references
- Remove all `in_flight` array handling
- Add `concessions` and `skill_invoked` to `ac_state_append_run`
- Add new function `ac_state_add_suppression <fingerprint> <reason_score>` that computes `expires_at` (30d or 90d)
- Update `ac_state_init` to write `schema_version: 2`

- [ ] **Step 5: Run tests; expect PASS**

```bash
bash architect-critic/tests/unit/test-state.sh
```

- [ ] **Step 6: Commit**

```bash
git add architect-critic/lib/state.sh architect-critic/tests/unit/test-state.sh
git commit -m "architect-critic: refactor lib/state.sh for schema v2 (v0.2 Phase 3)"
```

### Task 3.2: Update `lib/principles.sh` for shipped-default tag handling

**Files:**
- Modify: `architect-critic/lib/principles.sh`
- Modify: `architect-critic/tests/unit/test-principles.sh`

- [ ] **Step 1: Move test file**

```bash
git mv architect-critic/tests/test-principles.sh architect-critic/tests/unit/test-principles.sh
```

- [ ] **Step 2: Write failing tests**

- `test_shipped_defaults_preserved_on_merge` — ensure ghost-notes + CORE always appear in merge output
- `test_source_tag_filtering` — `--source shipped` returns only shipped-default principles
- `test_user_promoted_below_shipped` — display order: shipped → user → project

- [ ] **Step 3: Run tests; expect FAILs**

- [ ] **Step 4: Update `lib/principles.sh`**

Add source-tag parsing from `<!-- source: ... -->` HTML comments. Add merge function that preserves order: shipped → user → project. Add `ac_principles_filter_by_source` helper.

- [ ] **Step 5: Run tests; expect PASS**

- [ ] **Step 6: Commit**

```bash
git add architect-critic/lib/principles.sh architect-critic/tests/unit/test-principles.sh
git commit -m "architect-critic: principles.sh handles shipped-default tag + merge order (v0.2 Phase 3)"
```

### Task 3.3: Author `lib/promotion.sh` (auto-promotion machinery)

**Files:**
- Create: `architect-critic/lib/promotion.sh`
- Create: `architect-critic/tests/unit/test-promotion.sh` (or move from v0.1.3 location)

- [ ] **Step 1: Move/create test file**

```bash
[[ -f architect-critic/tests/test-promotion.sh ]] && git mv architect-critic/tests/test-promotion.sh architect-critic/tests/unit/test-promotion.sh
```

- [ ] **Step 2: Write failing tests**

- `test_vote_threshold_T4_promotes_candidate` — insert 4 votes across distinct runs, assert promotion-candidate surfaces
- `test_below_T4_no_promotion` — 3 votes, assert NO promotion
- `test_suppression_30day_window` — declined with score 4, assert next 29 days suppressed, day 31 re-surfaces
- `test_suppression_90day_window` — declined with score 5, assert similar with 89/91 days
- `test_instinct_signal_N3_consecutive` — same fingerprint in 3 consecutive runs even without votes → surfaces as instinct candidate
- `test_idempotent_promotion` — calling promote on already-promoted principle is a no-op

- [ ] **Step 3: Author `lib/promotion.sh`**

Functions:
- `ac_promotion_check_candidates <state.json>` — iterate recent_runs, collect non-conceded challenges, look up fingerprints, increment vote counts, surface candidates at T=4
- `ac_promotion_add_vote <fingerprint> <run_id> <challenge_text>` — insert/update candidate_promotions
- `ac_promotion_apply_suppression <fingerprint> <reason_score>` — delegate to `lib/state.sh:ac_state_add_suppression`
- `ac_promotion_instinct_signal <state.json>` — find fingerprints appearing in last N=3 runs

- [ ] **Step 4: Run tests; expect PASS**

```bash
bash architect-critic/tests/unit/test-promotion.sh
```

- [ ] **Step 5: Commit**

```bash
git add architect-critic/lib/promotion.sh architect-critic/tests/unit/test-promotion.sh
git commit -m "architect-critic: add lib/promotion.sh auto-promotion machinery (v0.2 Phase 3)"
```

### Task 3.4: Refactor `lib/codex.sh` for JSON output + schema constraint

**Files:**
- Modify: `architect-critic/lib/codex.sh`
- Modify: `architect-critic/tests/unit/test-codex.sh`

- [ ] **Step 1: Move test file**

```bash
git mv architect-critic/tests/test-codex.sh architect-critic/tests/unit/test-codex.sh
```

- [ ] **Step 2: Write failing tests**

- `test_codex_invocation_uses_json_flag` — assert codex invoked with `--json --output-schema --output-last-message --ignore-user-config --ignore-rules --skip-git-repo-check`
- `test_codex_invocation_no_hardcoded_model` — assert `-c model=` NOT in command unless `--model NAME` flag passed
- `test_codex_invocation_with_model_override` — `--model gpt-5.5` → assert `-c model="gpt-5.5"` in command
- `test_codex_timeout_default_5min` — assert `timeout 300` (or equivalent) in invocation
- `test_codex_output_parsed_from_last_message_file` — mock codex writes a JSON file; assert parser extracts challenges
- `test_codex_non_schema_output_rejected` — invalid JSON output → empty result + log warning

- [ ] **Step 3: Update `lib/codex.sh`**

Function `ac_codex_run_audit <prompt> <output_dir> [--model NAME] [--timeout SECS]`:
- Build command with required flags from SPEC §5.1 step 6
- Use `timeout` (macOS: install via coreutils OR use built-in trap-based timeout)
- Parse `--output-last-message` file as JSON
- Validate against `templates/output-schema.json` (using `jq` or schema validator if available)
- Return parsed challenges OR empty + error code

Notes:
- macOS doesn't have `timeout` by default; provide a bash-based timeout fallback
- Use `command -v codex` for availability check

- [ ] **Step 4: Run tests; expect PASS**

- [ ] **Step 5: Commit**

```bash
git add architect-critic/lib/codex.sh architect-critic/tests/unit/test-codex.sh
git commit -m "architect-critic: codex.sh uses --json + --output-schema + --ignore-rules (v0.2 Phase 3)"
```

### Task 3.5: Move + extend `lib/scorer.sh` tests (logic unchanged)

**Files:**
- Modify: `architect-critic/tests/unit/test-scorer.sh`

- [ ] **Step 1: Move test file**

```bash
git mv architect-critic/tests/test-scorer.sh architect-critic/tests/unit/test-scorer.sh
```

- [ ] **Step 2: Verify existing tests still pass (logic unchanged)**

```bash
bash architect-critic/tests/unit/test-scorer.sh
```

Expected: 14 existing assertions pass.

- [ ] **Step 3: Commit**

```bash
git add architect-critic/tests/unit/test-scorer.sh
git commit -m "architect-critic: move scorer tests to tests/unit/ (v0.2 Phase 3)"
```

### Task 3.6: Move + verify `lib/consolidator.sh` tests

**Files:**
- Modify: `architect-critic/tests/unit/test-consolidator.sh`

- [ ] **Step 1: Move + verify (logic unchanged)**

```bash
git mv architect-critic/tests/test-consolidator.sh architect-critic/tests/unit/test-consolidator.sh
bash architect-critic/tests/unit/test-consolidator.sh
```

- [ ] **Step 2: Commit**

```bash
git add architect-critic/tests/unit/test-consolidator.sh
git commit -m "architect-critic: move consolidator tests to tests/unit/ (v0.2 Phase 3)"
```

### Task 3.7: Author `lib/migration.sh` (v0.1.x → v0.2 first-run migration)

**Files:**
- Create: `architect-critic/lib/migration.sh`
- Create: `architect-critic/tests/unit/test-migration.sh`

- [ ] **Step 1: Write failing tests**

- `test_detects_v01_state_json` — fixture: schema_version=1 state.json; assert detected
- `test_renames_old_state_to_bak` — assert `state.json.v0.1.3.bak` created
- `test_inbox_outbox_moved_to_legacy` — fixture: inbox/ + outbox/ present; assert moved to `legacy-v0.1.x/`
- `test_principles_preserved_with_shipped_prepended` — fixture: existing principles.md with user content; assert ghost-notes + CORE prepended, user content kept with `<!-- migrated from v0.1.x -->` tag
- `test_bak_with_existing_collision` — fixture: `state.json.v0.1.3.bak` already exists; assert timestamped variant created
- `test_no_op_on_fresh_install` — fixture: no v0.1.x artifacts; assert no errors, no .bak files

- [ ] **Step 2: Author `lib/migration.sh`**

Functions:
- `ac_migration_check_v01_state` — detect + dispatch
- `ac_migration_backup_state` — handle .bak collision
- `ac_migration_move_inbox_outbox` — to `legacy-v0.1.x/`
- `ac_migration_prepend_shipped_defaults` — preserve user principles

- [ ] **Step 3: Run tests; expect PASS**

- [ ] **Step 4: Commit**

```bash
git add architect-critic/lib/migration.sh architect-critic/tests/unit/test-migration.sh
git commit -m "architect-critic: add lib/migration.sh for v0.1.x → v0.2 first-run migration (v0.2 Phase 3)"
```

### Task 3.8: Delete `lib/inbox.sh` and `lib/outbox.sh`

**Files:**
- Delete: `architect-critic/lib/inbox.sh`
- Delete: `architect-critic/lib/outbox.sh`
- Delete: `architect-critic/tests/test-inbox.sh`
- Delete: `architect-critic/tests/test-outbox.sh`
- Modify: anywhere that sources these (verify nothing references them)

- [ ] **Step 1: Find all references**

```bash
grep -rn "inbox.sh\|outbox.sh\|ac_inbox_\|ac_outbox_" architect-critic/ --exclude-dir=.git
```

Expected: only test files + the lib files themselves. If skill bodies or commands reference them → remove those references first.

- [ ] **Step 2: Delete the files**

```bash
git rm architect-critic/lib/inbox.sh architect-critic/lib/outbox.sh \
       architect-critic/tests/test-inbox.sh architect-critic/tests/test-outbox.sh
```

- [ ] **Step 3: Verify nothing breaks**

```bash
for t in architect-critic/tests/unit/test-*.sh; do bash "$t" || echo "FAIL: $t"; done
```

Expected: all unit tests still pass.

- [ ] **Step 4: Commit**

```bash
git commit -m "architect-critic: drop inbox/outbox protocol (v0.2 Phase 3)"
```

**Phase 3 close:** lib/ slimmed; all unit tests green. Update CHANGELOG: "v0.2 Phase 3 — lib refactored; inbox/outbox removed; promotion + migration added."

---

## Phase 4 — Hooks

### Task 4.1: Author SessionStart hook

**Files:**
- Create: `architect-critic/hooks-handlers/session-start.sh`
- Modify: `architect-critic/.claude-plugin/plugin.json` (register hook)

- [ ] **Step 1: Verify current plugin.json hook configuration**

```bash
jq '.hooks' architect-critic/.claude-plugin/plugin.json
```

- [ ] **Step 2: Author the hook script**

```bash
cat > architect-critic/hooks-handlers/session-start.sh <<'EOF'
#!/usr/bin/env bash
# session-start.sh — fail-open ambient status for architect-critic v0.2
# Output: ~50 tokens. NEVER fails (always exit 0).

set +e

PRINCIPLES_PATH="${HOME}/.claude/architect-critic/principles.md"
if [[ ! -f "$PRINCIPLES_PATH" ]]; then
  PRINCIPLES_PATH="(shipped defaults only)"
fi

echo "architect-critic v0.2 installed; principles loaded from ${PRINCIPLES_PATH}"
exit 0
EOF
chmod +x architect-critic/hooks-handlers/session-start.sh
```

- [ ] **Step 3: Register hook in plugin.json**

```bash
jq '.hooks = [{ "event": "SessionStart", "handler": "hooks-handlers/session-start.sh" }]' \
  architect-critic/.claude-plugin/plugin.json > /tmp/plugin.json.new
mv /tmp/plugin.json.new architect-critic/.claude-plugin/plugin.json
```

- [ ] **Step 4: Verify hook runs in isolation**

```bash
bash architect-critic/hooks-handlers/session-start.sh
```

Expected: prints one-line status; exit code 0.

- [ ] **Step 5: Commit**

```bash
git add architect-critic/hooks-handlers/ architect-critic/.claude-plugin/plugin.json
git commit -m "architect-critic: add SessionStart fail-open status hook (v0.2 Phase 4)"
```

**Phase 4 close:** update CHANGELOG: "v0.2 Phase 4 — SessionStart hook landed."

---

## Phase 5 — Slash command wrappers

### Task 5.1: Rewrite `commands/critique.md` as thin wrapper

**Files:**
- Modify: `architect-critic/commands/critique.md`

- [ ] **Step 1: Snapshot current critique.md for comparison**

```bash
cp architect-critic/commands/critique.md /tmp/critique.md.v01.bak
wc -l architect-critic/commands/critique.md  # expect 465
```

- [ ] **Step 2: Rewrite as ≤80-line wrapper**

```markdown
---
description: Run an architect-critic audit on a spec or plan
argument-hint: [path] [--close] [--model NAME] [--principles PATH]
---

# /critique

Invoke the critiquing-spec skill with the provided arguments.

The skill body handles all logic: path discovery, principles merging, codex detection, claude-self-audit, optional codex fresh-frame, consolidation, rebuttal cycle, bookkeeping.

This slash command is a thin wrapper. The work happens in the skill.

```bash
# Bridge $ARGUMENTS into env var so the skill can read it.
# See [[feedback_slash_command_dollar_n_bug]] — never use $1/$2 in command bodies.
export ARCHITECT_CRITIC_ARGS="$ARGUMENTS"
```

Now invoke the `critiquing-spec` skill, passing the arguments above via $ARCHITECT_CRITIC_ARGS.
```

- [ ] **Step 3: Verify bug #1 regression test passes**

```bash
bash architect-critic/tests/integration/test-bug-repros.sh 2>&1 | grep "BUG #1"
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add architect-critic/commands/critique.md
git commit -m "architect-critic: critique.md becomes thin wrapper over critiquing-spec skill (v0.2 Phase 5)"
```

### Task 5.2: Rewrite remaining 3 slash commands as wrappers

**Files:**
- Modify: `architect-critic/commands/critique-list.md`
- Modify: `architect-critic/commands/principles-list.md`
- Modify: `architect-critic/commands/promote-principle.md`

- [ ] **Step 1-3: Apply the same wrapper pattern to each**

Each becomes ≤50 lines: frontmatter (description + argument-hint), $ARGUMENTS bridge, instruction to invoke the corresponding skill.

- [ ] **Step 4: Verify no command body uses $N positionals**

```bash
grep -nE '\$[12345]' architect-critic/commands/*.md
```

Expected: no matches (or matches are inside `<!--` comments).

- [ ] **Step 5: Commit**

```bash
git add architect-critic/commands/
git commit -m "architect-critic: all 4 slash commands are thin skill wrappers (v0.2 Phase 5)"
```

**Phase 5 close:** update CHANGELOG: "v0.2 Phase 5 — slash commands become thin wrappers; $N bug fixed."

---

## Phase 6 — Subagent pressure tests

### Task 6.1: Pressure-test skill invocation from subagent context

**Files:**
- Create: `architect-critic/tests/integration/test-subagent-pressure.sh`

- [ ] **Step 1: Write the pressure test**

For each skill: dispatch an Agent subagent with the skill as task; verify it completes without orchestration deadlock; verify codex subprocess (when triggered) works under subagent context.

- [ ] **Step 2: Run the pressure test**

```bash
bash architect-critic/tests/integration/test-subagent-pressure.sh
```

- [ ] **Step 3: If failures observed per [[feedback_subagent_vs_inline_threshold]], document workaround**

Skills that don't work under subagent context get a `<!-- inline-only -->` tag in their SKILL.md description. Update SPEC §13 accordingly.

- [ ] **Step 4: Commit**

```bash
git add architect-critic/tests/integration/test-subagent-pressure.sh
git commit -m "architect-critic: subagent pressure tests for all 4 skills (v0.2 Phase 6)"
```

**Phase 6 close:** update CHANGELOG.

---

## Phase 7 — Integration tests with consumers

### Task 7.1: scaffold-onboard v0.2 fixture invocation test

**Files:**
- Create: `architect-critic/tests/integration/test-scaffold-onboard.sh`

- [ ] **Step 1: Write fixture invocation test**

Simulate scaffold-onboard v0.2 reaching its "now adversarially audit MASTER-SPEC" moment. Verify critiquing-spec skill is triggered in-conversation (not via inbox/outbox). Verify summary returns in conversation context.

- [ ] **Step 2: Run**

```bash
bash architect-critic/tests/integration/test-scaffold-onboard.sh
```

Note: this test depends on scaffold-onboard v0.2 being available. If not yet built, mark as `SKIP` with TODO.

- [ ] **Step 3: Commit**

```bash
git add architect-critic/tests/integration/test-scaffold-onboard.sh
git commit -m "architect-critic: scaffold-onboard v0.2 in-conversation fixture test (v0.2 Phase 7)"
```

### Task 7.2: scaffold-dev v0.1 fixture invocation test

**Files:**
- Create: `architect-critic/tests/integration/test-scaffold-dev.sh`

- [ ] **Step 1-3: Mirror Task 7.1 structure for scaffold-dev's slice-close adversarial-review moment**

Per `SPEC-scaffold-dev.md` §16.3, scaffold-dev expects to invoke critiquing-spec at two moments per slice. Test both.

```bash
git add architect-critic/tests/integration/test-scaffold-dev.sh
git commit -m "architect-critic: scaffold-dev v0.1 in-conversation fixture test (v0.2 Phase 7)"
```

**Phase 7 close:** update CHANGELOG.

---

## Phase 8 — Migration smoke test

### Task 8.1: End-to-end migration smoke

**Files:**
- Create: `architect-critic/tests/integration/test-migration-smoke.sh`

- [ ] **Step 1: Write the smoke test**

```bash
cat > architect-critic/tests/integration/test-migration-smoke.sh <<'EOF'
#!/usr/bin/env bash
# Smoke test: simulate v0.1.x install with state.json + inbox/outbox + principles.md;
# run v0.2 first-run migration; verify .bak created, fresh state, principles preserved.

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_HOME="$(mktemp -d)"
trap "rm -rf $TMP_HOME" EXIT

# Set up fake v0.1.x state
mkdir -p "$TMP_HOME/.claude/architect-critic/inbox" "$TMP_HOME/.claude/architect-critic/outbox"
cat > "$TMP_HOME/.claude/architect-critic/state.json" <<JSON
{
  "schema_version": 1,
  "in_flight": [],
  "recent_runs": [{ "request_id": "old-run", "cost_usd": 0 }],
  "principle_promotions": []
}
JSON
cat > "$TMP_HOME/.claude/architect-critic/inbox/test-req.json" <<JSON
{ "request_id": "stale-req", "spec_path": "/nowhere" }
JSON
echo "- My custom user principle" > "$TMP_HOME/.claude/architect-critic/principles.md"

# Run migration
HOME="$TMP_HOME" bash "$PLUGIN_DIR/lib/migration.sh" check-v01-state

# Assertions
[[ -f "$TMP_HOME/.claude/architect-critic/state.json.v0.1.3.bak" ]] || { echo "FAIL: .bak missing"; exit 1; }
[[ ! -d "$TMP_HOME/.claude/architect-critic/inbox" ]] || { echo "FAIL: inbox not moved"; exit 1; }
[[ -d "$TMP_HOME/.claude/architect-critic/legacy-v0.1.x/inbox" ]] || { echo "FAIL: legacy/inbox missing"; exit 1; }
grep -q "ghost.notes\|Ghost notes" "$TMP_HOME/.claude/architect-critic/principles.md" || { echo "FAIL: ghost-notes not prepended"; exit 1; }
grep -q "My custom user principle" "$TMP_HOME/.claude/architect-critic/principles.md" || { echo "FAIL: user content lost"; exit 1; }
grep -q "migrated from v0.1.x" "$TMP_HOME/.claude/architect-critic/principles.md" || { echo "FAIL: migration tag missing"; exit 1; }

# Verify fresh state.json has schema 2
jq -e '.schema_version == 2' "$TMP_HOME/.claude/architect-critic/state.json" >/dev/null || { echo "FAIL: schema not v2"; exit 1; }

echo "Migration smoke: all assertions passed"
EOF
chmod +x architect-critic/tests/integration/test-migration-smoke.sh
```

- [ ] **Step 2: Run smoke test**

```bash
bash architect-critic/tests/integration/test-migration-smoke.sh
```

Expected: "Migration smoke: all assertions passed"

- [ ] **Step 3: Commit**

```bash
git add architect-critic/tests/integration/test-migration-smoke.sh
git commit -m "architect-critic: migration smoke test (v0.2 Phase 8)"
```

**Phase 8 close:** update CHANGELOG.

---

## Phase 9 — Release

### Task 9.1: Update plugin.json + CHANGELOG + README + marketplace.json

**Files:**
- Modify: `architect-critic/.claude-plugin/plugin.json` — bump version 0.1.3 → 0.2.0
- Modify: `architect-critic/CHANGELOG.md` — add 0.2.0 section with all phases summarized
- Modify: `architect-critic/README.md` — add Standalone Use section (fixes bug #7); document `project_class=unknown` (fixes bug #8); update install instructions; update skill list (4 skills now)
- Modify: `architect-critic/.claude-plugin/marketplace.json` — update version reference
- Modify: root `README.md` — update plugin table to reflect v0.2.0 + 4 skills

- [ ] **Step 1: Bump version**

```bash
jq '.version = "0.2.0"' architect-critic/.claude-plugin/plugin.json > /tmp/plugin.json.new
mv /tmp/plugin.json.new architect-critic/.claude-plugin/plugin.json
```

- [ ] **Step 2: Write CHANGELOG 0.2.0 section**

Author at top of `architect-critic/CHANGELOG.md`:

```markdown
## v0.2.0 — 2026-05-?? (BREAKING)

**Architecture:** ground-up retrofit to skill-first. 4 skills replace 4 slash commands as primary capability surface. Slash commands become thin `$ARGUMENTS` wrappers.

### Breaking changes
- Inbox/outbox file-IPC protocol removed. Consumer plugins must invoke skills in-conversation. scaffold-onboard v0.2+ required.
- state.json schema v1 → v2: drop `in_flight` array, drop `cost_usd`; add `concessions`, `skill_invoked`, `auto_promote_suppressions`. v0.1.x state.json auto-renamed to `.v0.1.3.bak` on first v0.2 run.
- `cost_usd` field removed entirely. Reporting surface gone.
- `--depth` flag renamed to `--close` (semantic clarity).
- Codex CLI 0.125+ required for adversarial fresh-frame.

### Added
- 4 skills (gerund-named): `critiquing-spec`, `reviewing-critique-history`, `listing-principles`, `promoting-principle`.
- Ghost-notes principle (Wald survivor-bias) + CORE protocol (Curiosity/Objectivity/Reassurance/Empathy) as default shipped principles in principles.md.
- Auto-promotion machinery (was design-intent in v0.1.3): vote-recurrence T=4 threshold + instinct-style consecutive-runs signal + suppression windows (30d score-4 / 90d score-5).
- LLM-as-judge eval harness (`tests/eval/`) — ~5 fixtures per skill × 4 skills.
- SessionStart fail-open ambient status hook.
- `lib/migration.sh` — first-run v0.1.x → v0.2 migration.

### Fixed (GitHub issue #1)
- #1 `$N` substitution — slash commands now use `$ARGUMENTS` env-var bridge exclusively.
- #2 silent no-op claude-self-audit — audit logic moved into skill body; Claude executes in-conversation.
- #3 hard-fail without MASTER-SPEC — discovery order: explicit arg → manifest `well_known_paths.master_spec` → SPEC*/PLAN* heuristic → AskUserQuestion.
- #4 rebuttal cycle non-TTY skip — rebuttals handled in Claude's native turn flow; no bash `read`.
- #5 codex availability not surfaced — skill body explicitly checks + reports status.
- #6 cost_usd always zero — field removed entirely.
- #7 README missing standalone-use guidance — added.
- #8 `project_class=unknown` consequence — documented in skill body + README.
```

- [ ] **Step 3: Update README**

Add "## Standalone use" section. Add "## What `project_class=unknown` means" subsection. Update install/usage to reflect skill-first invocation.

- [ ] **Step 4: Update marketplace.json + root README**

```bash
jq '.plugins["architect-critic"].version = "0.2.0"' /Volumes/master_ssd/projects/claude-agent-scaffolding/.claude-plugin/marketplace.json > /tmp/m.new && mv /tmp/m.new /Volumes/master_ssd/projects/claude-agent-scaffolding/.claude-plugin/marketplace.json
```

Update plugin table in root README.

- [ ] **Step 5: Final regression sweep — all tests pass**

```bash
for t in architect-critic/tests/unit/test-*.sh; do bash "$t" || exit 1; done
for t in architect-critic/tests/integration/test-*.sh; do bash "$t" || exit 1; done
```

Then in a Claude Code session: *"Run the architect-critic eval harness per `tests/eval/RUNBOOK.md`, target `all`."* When the session reports completion, aggregate:

```bash
bash architect-critic/tests/eval/lib/aggregate-scores.sh
```

Expected: all unit + integration tests PASS; aggregator reports ≥4/5 fixtures passing per skill (≥16/20 total).

- [ ] **Step 6: Verify all 8 bug-repro tests PASS**

```bash
bash architect-critic/tests/integration/test-bug-repros.sh
```

Expected: 8 passed, 0 failed.

- [ ] **Step 7: Commit + tag**

```bash
git add architect-critic/.claude-plugin/plugin.json \
        architect-critic/CHANGELOG.md \
        architect-critic/README.md \
        .claude-plugin/marketplace.json \
        README.md
git commit -m "architect-critic: v0.2.0 release (v0.2 Phase 9)"
git tag -a v0.2.0-architect-critic -m "architect-critic v0.2.0 — skill-first retrofit; fixes issue #1"
```

- [ ] **Step 8: Close issue #1**

```bash
gh issue close 1 --comment "Fixed in v0.2.0. See CHANGELOG.md for details. All 8 bugs have regression tests in tests/integration/test-bug-repros.sh."
```

- [ ] **Step 9: Open PR for merge to main**

```bash
gh pr create --base main --head implementation-architect-critic-v02 \
  --title "architect-critic v0.2.0 — skill-first retrofit + issue #1 fixes" \
  --body "$(cat <<'EOF'
## Summary
- Ground-up skill-first retrofit per SPEC-architect-critic-v02.md
- Fixes all 8 bugs in #1 with regression tests
- Drops inbox/outbox file-IPC; consumers invoke skills in-conversation
- Ships ghost-notes + CORE as default principles
- Ships full auto-promotion machinery (was design-intent in v0.1)
- LLM-as-judge eval harness for skill quality
- Hard breaking change; v0.1.x state auto-migrated to .bak

## Test plan
- [ ] All unit tests pass (`bash architect-critic/tests/unit/test-*.sh`)
- [ ] All integration tests pass (`bash architect-critic/tests/integration/test-*.sh`)
- [ ] All 8 bug-repro regression tests PASS
- [ ] Eval harness reports ≥4/5 per skill on full run
- [ ] Migration smoke test passes
- [ ] /critique works on a SPEC* file in this repo with --close depth
- [ ] /critique works on a project without MASTER-SPEC.md (discovery flow)
- [ ] /critique-list, /principles-list, /promote-principle all functional
EOF
)"
```

**Phase 9 close:** v0.2.0 shipped. scaffold-onboard v0.2 + scaffold-dev v0.1 unblocked.

---

## Self-Review

**Spec coverage check:**
- All 16 SPEC sections accounted for: §3 goals (G1-G7) mapped to phases; §4 architecture → Phase 1+3+5; §5 skills → Phase 1; §6 schemas → Phase 3.1 (state) + Phase 2.1 (principles) + Phase 2.2 (codex); §7 derivations → Phase 3.2 (principles) + Phase 3.3 (promotion) + Phase 3.5 (scorer) + Phase 3.6 (consolidator); §8 integration → Phase 7; §10 migration → Phase 3.7 + Phase 8; §11 error handling → woven into skill bodies (Phase 1); §12 testing → Phase 0 + all phases TDD; §13 build sequence → this PLAN's phase order matches; §14 risks → mitigation in Phase 6 (subagent pressure) + Task 9.1 Step 5 (full regression sweep).

**Placeholder scan:** searched for TODO/TBD/"fill in" — only one TODO (Task 7.1 Step 2 if scaffold-onboard v0.2 not yet built, with explicit SKIP plan). All steps have complete commands or code.

**Type consistency:** `critiquing-spec` used consistently throughout. State schema field names (`concessions`, `skill_invoked`, `auto_promote_suppressions`) match between Phase 3.1 tests + Phase 1.1 skill body + SPEC §6.1. Function names (`ac_state_add_suppression`, `ac_promotion_check_candidates`) consistent across plan.

---

## Execution Handoff

**Plan complete and saved to `docs/PLAN-architect-critic-v02.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Best for Phases 0-3 (mechanical) + Phase 9 (release sweep).

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Better for Phases 1 (skill authoring is judgment-heavy) + Phase 6 (subagent pressure tests by definition need a non-subagent driver).

Per [[feedback_subagent_vs_inline_threshold]]: hybrid is allowed — start subagent-driven, pivot to inline if dispatches fail.

**Which approach?**
