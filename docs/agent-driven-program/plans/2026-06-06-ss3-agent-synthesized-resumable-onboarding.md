# SS-3 Agent-Synthesized, Resumable Onboarding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace mechanical MASTER-SPEC transcription with agent synthesis at Phase-10 close, driven by an enriched, resumable `onboarding-state.json` that stores agent-authored per-phase reasoning beside verbatim answers — with no deterministic MASTER-SPEC renderer anywhere.

**Architecture:** The conducting (main) agent authors a rich `phase_record` (decisions/rationale/alternatives/constraints/critic-outcomes) into state at each phase close, alongside the verbatim `answers` already captured. At Phase-10 close, a synthesis sub-agent (or, if dispatch is unavailable, the main orchestration context) reads a digest of that state through a **tool-agnostic** brief and authors the whole MASTER-SPEC — *first-author* mode on a fresh project, *reconcile* mode (refresh only phases touched this run, preserve untouched sections + human edits) on a re-run. The existing SS-2 EXEC-SUMMARY synthesis then runs unchanged from the new MASTER-SPEC. The deterministic transcription path (`sf_master_spec_init` / `sf_master_spec_update_phase` + the `{{phase_*}}` template) is deleted.

**Tech Stack:** Bash 3.2 (macOS-portable, BSD awk), `jq` for JSON state, the `sf` dispatcher, plugin synthesis briefs (markdown w/ YAML frontmatter), `Task()` sub-agent dispatch (`scaffold-onboard:synthesis-agent`), bash test suites under `tests/test-*.sh` sourced via `_helpers.sh`.

**Spec:** `docs/agent-driven-program/specs/SS-3-agent-synthesized-resumable-onboarding.md`

---

## File Structure

**Modified:**
- `scaffold-onboard/lib/state.sh` — add `schema_version`+`phase_records`+`touched_this_run` to init; new helpers `sf_state_write_phase_record`, `sf_state_read_phase_record`, `sf_state_run_reset`, `sf_state_phases_touched_this_run`, `sf_state_synthesis_digest`. Reads tolerate legacy files (missing keys → `// {}` / `// []`).
- `scaffold-onboard/lib/render.sh` — **remove** `sf_master_spec_init` + `sf_master_spec_update_phase` (deterministic transcription). Keep `sf_master_spec_section`, `_sf_master_spec_replace_section_body`, and the three SS-2 `sf_render_executive_summary*` fns untouched.
- `scaffold-onboard/lib/synthesis.sh` — add `sf_synth_master_spec_prompt` (assembles the MASTER-SPEC synthesis prompt from a state digest; first-author vs reconcile).
- `scaffold-onboard/skills/onboarding-project/SKILL.md` — §3 per-phase loop (author phase record instead of rendering a section; recap = echo from record), §8 close ceremony (synthesis dispatch + main-context-inline fallback + pre-write backup), §10/§12 helper/anti-pattern references.
- `scaffold-onboard/plugin.json` + Codex manifest + README version table — version bump (parity).

**Created:**
- `scaffold-onboard/templates/synthesis-briefs/MASTER-SPEC.brief.md` — tool-agnostic synthesis brief (state digest → MASTER-SPEC, emits a fillable `## Executive Summary` section).
- `scaffold-onboard/tests/test-phase-records.sh` — state schema + phase-record + touched-run + digest + legacy-migration units.
- `scaffold-onboard/tests/test-master-spec-synthesis.sh` — brief validity, prompt-assembler (first-author/reconcile), behavioral close-ceremony harness, no-deterministic-path guard.

**Removed:**
- `scaffold-onboard/templates/master-spec/MASTER-SPEC.md.tmpl` — the `{{phase_*}}` transcription template (after confirming no remaining caller). `EXECUTIVE-SUMMARY.md.tmpl` stays (SS-2 uses it).

---

## Task 1: State schema bump — `phase_records` + `schema_version`

**Files:**
- Modify: `scaffold-onboard/lib/state.sh:38-58` (`sf_state_init`)
- Test: `scaffold-onboard/tests/test-phase-records.sh`

- [ ] **Step 1: Write the failing test**

Create `scaffold-onboard/tests/test-phase-records.sh`:

```bash
#!/usr/bin/env bash
# test-phase-records.sh — SS-3: enriched state schema, phase records,
# touched-this-run tracking, synthesis digest, legacy migration.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/routing.sh"

test_init_has_schema_v2_and_phase_records() {
  echo "test_init_has_schema_v2_and_phase_records:"
  setup_tmp_repo
  sf_state_init
  assert_file_contains "$(sf_state_path)" '"schema_version": 2'
  assert_file_contains "$(sf_state_path)" '"phase_records": \{\}'
  assert_file_contains "$(sf_state_path)" '"touched_this_run": \[\]'
}

report_results
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scaffold-onboard/tests/test-phase-records.sh`
Expected: FAIL — `phase_records`/`schema_version`/`touched_this_run` absent from the init JSON.

- [ ] **Step 3: Add the fields to `sf_state_init`**

In `lib/state.sh`, edit the `jq -n` object in `sf_state_init` (lines 45-57) to add three keys:

```bash
  jq -n \
    --arg now "$now" \
    --arg root "$project_root" \
    '{
      schema_version: 2,
      status: "in_progress",
      current_phase: 1,
      current_question: null,
      project_class: null,
      project_root: $root,
      created_at: $now,
      updated_at: $now,
      answers: {},
      phase_records: {},
      touched_this_run: []
    }' > "$path"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash scaffold-onboard/tests/test-phase-records.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/state.sh scaffold-onboard/tests/test-phase-records.sh
git commit -m "feat(scaffold-onboard): SS-3 state schema v2 — phase_records + touched_this_run"
```

---

## Task 2: Phase-record write/read + touched-this-run tracking

**Files:**
- Modify: `scaffold-onboard/lib/state.sh` (add helpers after `sf_state_read_answer`, ~line 118)
- Test: `scaffold-onboard/tests/test-phase-records.sh`

- [ ] **Step 1: Write the failing tests**

Add to `test-phase-records.sh` before `report_results`:

```bash
test_phase_record_round_trip() {
  echo "test_phase_record_round_trip:"
  setup_tmp_repo
  sf_state_init
  local rec="$TMP_DIR/rec3.json"
  cat > "$rec" <<'JSON'
{
  "decisions": "Store data in a single JSON file under ~/.app.",
  "rationale": "Zero-dependency persistence; user requested no DB.",
  "alternatives_rejected": "SQLite (overkill for <1k rows).",
  "constraints": "Must survive a kill -9 mid-write (atomic rename).",
  "open_questions": "Encryption at rest?",
  "critic_outcomes": "premise-audit: single-file lock contention flagged; accepted advisory note."
}
JSON
  sf_state_write_phase_record 3 "$rec"
  local got
  got="$(sf_state_read_phase_record 3 | jq -r '.decisions')"
  assert_eq "decisions round-trip" "Store data in a single JSON file under ~/.app." "$got"
}

test_phase_record_rejects_invalid_json() {
  echo "test_phase_record_rejects_invalid_json:"
  setup_tmp_repo
  sf_state_init
  local bad="$TMP_DIR/bad.json"
  printf 'not json {{' > "$bad"
  assert_exit_code 1 sf_state_write_phase_record 3 "$bad"
}

test_read_missing_phase_record_is_null() {
  echo "test_read_missing_phase_record_is_null:"
  setup_tmp_repo
  sf_state_init
  assert_eq "missing record reads null" "null" "$(sf_state_read_phase_record 7)"
}

test_touched_this_run_tracks_writes() {
  echo "test_touched_this_run_tracks_writes:"
  setup_tmp_repo
  sf_state_init
  local rec="$TMP_DIR/r.json"; printf '{"decisions":"x"}' > "$rec"
  sf_state_write_phase_record 1 "$rec"
  sf_state_write_phase_record 3 "$rec"
  sf_state_write_phase_record 1 "$rec"   # duplicate phase — must not double-list
  assert_eq "touched is unique+sorted" "1 3" "$(sf_state_phases_touched_this_run | tr '\n' ' ' | sed 's/ $//')"
}

test_run_reset_clears_touched() {
  echo "test_run_reset_clears_touched:"
  setup_tmp_repo
  sf_state_init
  local rec="$TMP_DIR/r.json"; printf '{"decisions":"x"}' > "$rec"
  sf_state_write_phase_record 4 "$rec"
  sf_state_run_reset
  assert_eq "touched empty after reset" "" "$(sf_state_phases_touched_this_run | tr -d '\n')"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scaffold-onboard/tests/test-phase-records.sh`
Expected: FAIL — `sf_state_write_phase_record` / `sf_state_read_phase_record` / `sf_state_phases_touched_this_run` / `sf_state_run_reset` not defined.

- [ ] **Step 3: Implement the helpers**

In `lib/state.sh`, insert after `sf_state_read_answer` (after line 118):

```bash
# Write a per-phase reasoning record. <record_file> must be a file containing a
# JSON object (the conducting agent authors it via its Write tool — keeps prose
# escaping out of bash). Merges into .phase_records["<phase_id>"] atomically and
# appends <phase_id> to .touched_this_run (unique). Bumps schema_version to 2 so
# a legacy file becomes conformant on first write.
sf_state_write_phase_record() {
  local phase_id="$1" record_file="$2"
  local path; path="$(sf_state_path)"
  if [[ ! -f "$record_file" ]]; then
    sf_log_error "sf_state_write_phase_record: record file not found: $record_file"
    return 1
  fi
  if ! jq -e . "$record_file" >/dev/null 2>&1; then
    sf_log_error "sf_state_write_phase_record: record file is not valid JSON: $record_file"
    return 1
  fi
  local tmp now
  tmp="$(mktemp "${path}.XXXXXX")"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq --arg p "$phase_id" --arg now "$now" --slurpfile rec "$record_file" \
    '
    .schema_version = 2
    | .phase_records = (.phase_records // {})
    | .phase_records[$p] = ($rec[0] + {authored_at: $now})
    | .touched_this_run = (((.touched_this_run // []) + [$p]) | unique)
    | .updated_at = $now
    ' "$path" > "$tmp"
  mv "$tmp" "$path"
}

# Read .phase_records["<phase_id>"] as a JSON object. Prints "null" if absent.
sf_state_read_phase_record() {
  local phase_id="$1"
  local path; path="$(sf_state_path)"
  if [[ ! -f "$path" ]]; then echo "null"; return 0; fi
  jq -c --arg p "$phase_id" '.phase_records[$p] // null' "$path"
}

# Reset the per-run touched-phases tracker. Call once at skill entry / resume so
# the reconcile hint reflects only phases (re)authored in the current run.
sf_state_run_reset() {
  local path; path="$(sf_state_path)"
  [[ -f "$path" ]] || return 0
  local tmp; tmp="$(mktemp "${path}.XXXXXX")"
  jq '.touched_this_run = []' "$path" > "$tmp"
  mv "$tmp" "$path"
}

# Print phase IDs (re)authored in the current run, one per line, sorted.
# Mechanical reconcile hint handed to the synthesis agent.
sf_state_phases_touched_this_run() {
  local path; path="$(sf_state_path)"
  [[ -f "$path" ]] || return 0
  jq -r '(.touched_this_run // []) | sort_by(tonumber) | .[]' "$path"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scaffold-onboard/tests/test-phase-records.sh`
Expected: PASS (5 new cases + Task 1's case).

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/state.sh scaffold-onboard/tests/test-phase-records.sh
git commit -m "feat(scaffold-onboard): SS-3 phase-record write/read + touched-this-run tracking"
```

---

## Task 3: Legacy-state migration tolerance (upgrade input class)

**Files:**
- Test: `scaffold-onboard/tests/test-phase-records.sh`
- (No code change expected — this verifies the `// {}` / `// []` tolerance from Task 2.)

- [ ] **Step 1: Write the failing test**

Add to `test-phase-records.sh`:

```bash
test_legacy_state_migrates_on_write() {
  echo "test_legacy_state_migrates_on_write:"
  setup_tmp_repo
  # A pre-SS-3 (v0.2.x) state file: no schema_version, no phase_records,
  # no touched_this_run — only flat answers. This is the upgrade input class.
  local path; path="$(sf_state_path)"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<JSON
{
  "status": "in_progress",
  "current_phase": 4,
  "project_root": "$(sf_project_identity_root)",
  "created_at": "2026-06-01T00:00:00Z",
  "updated_at": "2026-06-01T00:00:00Z",
  "answers": { "1.1.1": "legacy-app — a thing", "1.3.1": "CLI tool" }
}
JSON
  # Reads must not crash on the missing keys.
  assert_eq "legacy read_phase_record null" "null" "$(sf_state_read_phase_record 1)"
  assert_eq "legacy touched empty" "" "$(sf_state_phases_touched_this_run | tr -d '\n')"
  # First write upgrades the file without dropping the legacy answers.
  local rec="$TMP_DIR/r.json"; printf '{"decisions":"keep going"}' > "$rec"
  sf_state_write_phase_record 4 "$rec"
  assert_file_contains "$path" '"schema_version": 2'
  assert_eq "legacy answer preserved" "legacy-app — a thing" "$(sf_state_read_answer 1.1.1)"
  assert_eq "new record present" "keep going" "$(sf_state_read_phase_record 4 | jq -r '.decisions')"
}
```

- [ ] **Step 2: Run test**

Run: `bash scaffold-onboard/tests/test-phase-records.sh`
Expected: PASS immediately (the Task-2 helpers already use `// {}` / `// []` and `.schema_version = 2`). If it FAILS, the tolerance is missing — fix the helpers, do not weaken the test.

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/tests/test-phase-records.sh
git commit -m "test(scaffold-onboard): SS-3 legacy-state migration tolerance (upgrade input class)"
```

---

## Task 4: State synthesis digest

**Files:**
- Modify: `scaffold-onboard/lib/state.sh` (add `sf_state_synthesis_digest` after the helpers from Task 2)
- Test: `scaffold-onboard/tests/test-phase-records.sh`

- [ ] **Step 1: Write the failing test**

Add to `test-phase-records.sh`:

```bash
test_synthesis_digest_includes_answers_and_records() {
  echo "test_synthesis_digest_includes_answers_and_records:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.1.1" "todo-cli — a fast task manager"
  sf_state_write_answer "1.3.1" "CLI tool"
  local rec="$TMP_DIR/r1.json"
  printf '{"decisions":"single JSON file","rationale":"no DB requested"}' > "$rec"
  sf_state_write_phase_record 1 "$rec"
  local digest; digest="$(sf_state_synthesis_digest)"
  printf '%s' "$digest" | grep -q "1.1.1" || { echo "  ✗ missing qid"; exit 1; }
  printf '%s' "$digest" | grep -q "todo-cli — a fast task manager" || { echo "  ✗ missing raw answer"; exit 1; }
  printf '%s' "$digest" | grep -q "single JSON file" || { echo "  ✗ missing record decision"; exit 1; }
  printf '%s' "$digest" | grep -q "no DB requested" || { echo "  ✗ missing record rationale"; exit 1; }
  PASS=$((PASS+1)); echo "  ✓ digest carries answers + phase records"
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scaffold-onboard/tests/test-phase-records.sh`
Expected: FAIL — `sf_state_synthesis_digest` not defined.

- [ ] **Step 3: Implement `sf_state_synthesis_digest`**

Append to `lib/state.sh` (after `sf_state_phases_touched_this_run`):

```bash
# Emit a human-readable markdown digest of the enriched state for the MASTER-SPEC
# synthesis agent: per phase, the verbatim answers (qid: value) followed by the
# agent-authored phase record fields (if any). This is the synthesis SOURCE — it
# replaces template transcription. Tool-agnostic: any agent that can read text
# can consume it.
sf_state_synthesis_digest() {
  local path; path="$(sf_state_path)"
  [[ -f "$path" ]] || { sf_log_error "sf_state_synthesis_digest: no state file"; return 1; }
  echo "# Onboarding discussion digest"
  echo ""
  echo "Project: $(sf_project_name)"
  echo ""
  local phase
  for phase in 1 2 3 4 5 6 7 8 9 10; do
    echo "## Phase $phase"
    echo ""
    echo "### Answers (verbatim)"
    # Answers whose qid belongs to this phase. Phase 6 is split into gated
    # subtracks (6A/6B) in phases.yaml, so include those prefixes as phase 6.
    jq -r --arg p "$phase" '
      .answers // {}
      | to_entries
      | map(select(.key | startswith($p + ".") or ($p == "6" and test("^6[AB]\\."))))
      | sort_by(.key)
      | .[] | "- \(.key): \(.value)"
    ' "$path"
    echo ""
    local rec
    rec="$(jq -c --arg p "$phase" '.phase_records[$p] // null' "$path")"
    if [[ "$rec" != "null" ]]; then
      echo "### Synthesized phase record"
      printf '%s\n' "$rec" | jq -r '
        to_entries
        | map(select(.key != "authored_at"))
        | .[] | "- **\(.key)**: \(.value)"
      '
      echo ""
    fi
  done
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash scaffold-onboard/tests/test-phase-records.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/state.sh scaffold-onboard/tests/test-phase-records.sh
git commit -m "feat(scaffold-onboard): SS-3 state synthesis digest (answers + phase records)"
```

---

## Task 5: MASTER-SPEC synthesis brief (tool-agnostic)

**Files:**
- Create: `scaffold-onboard/templates/synthesis-briefs/MASTER-SPEC.brief.md`
- Test: `scaffold-onboard/tests/test-master-spec-synthesis.sh`

- [ ] **Step 1: Write the failing test**

Create `scaffold-onboard/tests/test-master-spec-synthesis.sh`:

```bash
#!/usr/bin/env bash
# test-master-spec-synthesis.sh — SS-3: MASTER-SPEC synthesis brief, prompt
# assembler (first-author/reconcile), behavioral close harness, no-determinism guard.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
ROOT="$HERE/.."
source "$ROOT/lib/state.sh"
source "$ROOT/lib/synthesis.sh"
source "$ROOT/lib/routing.sh"
BRIEF="$ROOT/templates/synthesis-briefs/MASTER-SPEC.brief.md"

test_brief_exists_and_valid_frontmatter() {
  echo "test_brief_exists_and_valid_frontmatter:"
  assert_file_exists "$BRIEF"
  assert_file_contains "$BRIEF" '^doc: MASTER-SPEC'
  assert_file_contains "$BRIEF" '^routes_to: master_spec'
  # Must instruct emitting a fillable Executive Summary section for the SS-2 step.
  assert_file_contains "$BRIEF" '## Executive Summary'
}

test_brief_is_tool_agnostic() {
  echo "test_brief_is_tool_agnostic:"
  # Zero Claude-isms: no "Claude", no Anthropic-specific tool names in the body.
  assert_file_not_contains "$BRIEF" 'Claude'
  assert_file_not_contains "$BRIEF" 'Anthropic'
}

report_results
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scaffold-onboard/tests/test-master-spec-synthesis.sh`
Expected: FAIL — brief file does not exist.

- [ ] **Step 3: Create the brief**

Create `scaffold-onboard/templates/synthesis-briefs/MASTER-SPEC.brief.md`:

```markdown
---
doc: MASTER-SPEC
routes_to: master_spec
wave: 0
required_sections:
  - "Executive Summary"
mints: []
consumes: []
model: sonnet
---
## Synthesis guidance

You are authoring `MASTER-SPEC.md`, the project's source-of-truth specification,
from the onboarding discussion digest provided in the prompt. The digest holds,
per phase (1–10): the participant's verbatim answers AND a synthesized phase
record (decisions, rationale, rejected alternatives, constraints, open questions,
critic outcomes). SYNTHESIZE — do not transcribe. Turn the raw answers and the
phase records into coherent specification prose in the project's own domain
vocabulary. Never emit fill-in markers, `TODO:`, or `{{placeholder}}` tokens.

Cover the ten role-scoped phases as MASTER-SPEC sections: Foundation, Strategy,
Domain & Data Model, Security & Compliance, Architecture, UX / Surfaces,
Implementation Approach, DevOps & Environments, Quality/Testing/Eval, Operations
& Support. Omit a phase section only when its digest has no answers and no record.

You MUST include a `## Executive Summary` section. Emit it as a short prose
placeholder line (one sentence) — a separate step synthesizes the authoritative
summary and pins it into this section, so keep it prose-only here: NO `##`
subheadings, NO `---`/`***`/`___` horizontal rules, NO HTML comments inside it.

### Mode

The prompt states the mode:

- **first-author** — no existing MASTER-SPEC. Author the whole document fresh.
- **reconcile** — an existing MASTER-SPEC is provided (read it in full). Refresh
  ONLY the phases listed as "touched this run"; reproduce every other section
  verbatim, preserving any human edits. Do not reorder or restyle untouched
  sections. The Executive Summary section is owned by the separate summary step —
  carry it through unchanged in reconcile mode.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash scaffold-onboard/tests/test-master-spec-synthesis.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/templates/synthesis-briefs/MASTER-SPEC.brief.md scaffold-onboard/tests/test-master-spec-synthesis.sh
git commit -m "feat(scaffold-onboard): SS-3 tool-agnostic MASTER-SPEC synthesis brief"
```

---

## Task 6: MASTER-SPEC prompt assembler (`sf_synth_master_spec_prompt`)

**Files:**
- Modify: `scaffold-onboard/lib/synthesis.sh` (add fn; place after `sf_synth_brief_assemble`, ~line 203)
- Test: `scaffold-onboard/tests/test-master-spec-synthesis.sh`

- [ ] **Step 1: Write the failing tests**

Add to `test-master-spec-synthesis.sh` (before `report_results`):

```bash
_seed_min_state() {
  sf_state_init
  sf_state_write_answer "1.1.1" "todo-cli — a fast task manager"
  sf_state_write_answer "1.3.1" "CLI tool"
}

test_prompt_first_author_contains_digest_and_mode() {
  echo "test_prompt_first_author_contains_digest_and_mode:"
  setup_tmp_repo
  _seed_min_state
  local digest out prompt
  digest="$(sf_state_synthesis_digest)"
  out="$TMP_DIR/repo/MASTER-SPEC.md"
  prompt="$(sf_synth_master_spec_prompt "$BRIEF" "$digest" "$out" first_author "" "")"
  printf '%s' "$prompt" | grep -q "todo-cli — a fast task manager" || { echo "  ✗ digest not embedded"; exit 1; }
  printf '%s' "$prompt" | grep -qi "MODE: first-author" || { echo "  ✗ mode missing"; exit 1; }
  printf '%s' "$prompt" | grep -q "$out" || { echo "  ✗ out path missing"; exit 1; }
  PASS=$((PASS+1)); echo "  ✓ first-author prompt assembled"
}

test_prompt_reconcile_lists_touched_and_existing() {
  echo "test_prompt_reconcile_lists_touched_and_existing:"
  setup_tmp_repo
  _seed_min_state
  local existing="$TMP_DIR/repo/MASTER-SPEC.md"
  printf '# todo-cli\n\n## Phase 1\nold content\n' > "$existing"
  local digest prompt
  digest="$(sf_state_synthesis_digest)"
  prompt="$(sf_synth_master_spec_prompt "$BRIEF" "$digest" "$existing" reconcile "1 5" "$existing")"
  printf '%s' "$prompt" | grep -qi "MODE: reconcile" || { echo "  ✗ reconcile mode missing"; exit 1; }
  printf '%s' "$prompt" | grep -q "touched this run: 1 5" || { echo "  ✗ touched list missing"; exit 1; }
  printf '%s' "$prompt" | grep -q "$existing" || { echo "  ✗ existing spec path missing"; exit 1; }
  PASS=$((PASS+1)); echo "  ✓ reconcile prompt assembled"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scaffold-onboard/tests/test-master-spec-synthesis.sh`
Expected: FAIL — `sf_synth_master_spec_prompt` not defined.

- [ ] **Step 3: Implement the assembler**

Append to `lib/synthesis.sh`:

```bash
# Assemble the MASTER-SPEC synthesis prompt. Unlike sf_synth_brief_assemble
# (which synthesizes a downstream artifact FROM MASTER-SPEC), this synthesizes
# MASTER-SPEC itself FROM the onboarding discussion digest.
# Args: <brief> <digest_file> <out_path> <mode> <touched> <existing_spec_path>
#   mode = first_author | reconcile
#   digest is passed as a FILE PATH (not inline text) to avoid ARG_MAX on large
#   sessions; touched / existing_spec_path are used only in reconcile mode.
#   NOTE (shipped contract): the function validates mode ∈ {first_author,reconcile}
#   and guards the digest file is readable before assembling the prompt.
sf_synth_master_spec_prompt() {
  local brief="$1" digest_file="$2" out_path="$3" mode="$4" touched="$5" existing="$6"
  [[ -f "$digest_file" && -r "$digest_file" ]] || return 1
  [[ "$mode" == "first_author" || "$mode" == "reconcile" ]] || return 1
  local digest; digest="$(cat "$digest_file")"
  local body
  body="$(awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{f=0;skip=1;next} skip{print}' "$brief")"

  local mode_block
  if [[ "$mode" == "reconcile" ]]; then
    mode_block="MODE: reconcile
An existing MASTER-SPEC is at: $existing — read it in full.
Refresh ONLY these phases, touched this run: ${touched:-(none)}
Reproduce every other section verbatim, preserving human edits."
  else
    mode_block="MODE: first-author
No existing MASTER-SPEC. Author the whole document fresh."
  fi

  cat <<EOF
You are synthesizing the project's MASTER-SPEC.md from the onboarding discussion
digest below.

Write the artifact to: $out_path

$mode_block

--- BEGIN DISCUSSION DIGEST ---
$digest
--- END DISCUSSION DIGEST ---

$body
EOF
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scaffold-onboard/tests/test-master-spec-synthesis.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/synthesis.sh scaffold-onboard/tests/test-master-spec-synthesis.sh
git commit -m "feat(scaffold-onboard): SS-3 MASTER-SPEC prompt assembler (first-author + reconcile)"
```

---

## Task 7: Retire the deterministic transcription path

**Files:**
- Modify: `scaffold-onboard/lib/render.sh:391-468` (remove `sf_master_spec_init` + `sf_master_spec_update_phase`)
- Remove: `scaffold-onboard/templates/master-spec/MASTER-SPEC.md.tmpl`
- Test: `scaffold-onboard/tests/test-master-spec-synthesis.sh`

- [ ] **Step 1: Confirm no other caller**

Run: `grep -rn "sf_master_spec_update_phase\|sf_master_spec_init\|MASTER-SPEC.md.tmpl" scaffold-onboard --include='*.sh' --include='*.md' | grep -v tests/`
Expected before edit: hits only in `lib/render.sh`, `skills/onboarding-project/SKILL.md`, and possibly `references/`. (The SKILL.md references are removed in Task 8/9.) If any OTHER lib/command references them, note it — those callers must move to synthesis first.

- [ ] **Step 2: Write the failing guard test**

Add to `test-master-spec-synthesis.sh`:

```bash
test_no_deterministic_master_spec_renderer() {
  echo "test_no_deterministic_master_spec_renderer:"
  source "$ROOT/lib/render.sh"
  if declare -F sf_master_spec_update_phase >/dev/null 2>&1; then
    FAIL=$((FAIL+1)); echo "  ✗ sf_master_spec_update_phase still defined"
  else
    PASS=$((PASS+1)); echo "  ✓ sf_master_spec_update_phase removed"
  fi
  if declare -F sf_master_spec_init >/dev/null 2>&1; then
    FAIL=$((FAIL+1)); echo "  ✗ sf_master_spec_init still defined"
  else
    PASS=$((PASS+1)); echo "  ✓ sf_master_spec_init removed"
  fi
  assert_file_missing "$ROOT/templates/master-spec/MASTER-SPEC.md.tmpl"
  # SS-2 exec-summary fns must still exist (not collateral damage).
  if declare -F sf_render_executive_summary >/dev/null 2>&1; then
    PASS=$((PASS+1)); echo "  ✓ SS-2 sf_render_executive_summary intact"
  else
    FAIL=$((FAIL+1)); echo "  ✗ SS-2 sf_render_executive_summary removed by mistake"
  fi
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bash scaffold-onboard/tests/test-master-spec-synthesis.sh`
Expected: FAIL — both functions still defined, template still present.

- [ ] **Step 4: Remove the functions and template**

Delete `sf_master_spec_init` (render.sh:391-404) and `sf_master_spec_update_phase` (render.sh:406-468) entirely, including their leading comment blocks. Then:

```bash
git rm scaffold-onboard/templates/master-spec/MASTER-SPEC.md.tmpl
```

- [ ] **Step 5: Run test to verify it passes + run the render/state suites**

Run: `bash scaffold-onboard/tests/test-master-spec-synthesis.sh`
Run: `bash scaffold-onboard/tests/test-render.sh`
Expected: synthesis guard PASSES; `test-render.sh` PASSES (if it referenced the removed fns, update those cases to assert removal — the deterministic transcription path is intentionally gone, do not re-add it).

- [ ] **Step 6: Commit**

```bash
git add -A scaffold-onboard/lib/render.sh scaffold-onboard/templates/master-spec scaffold-onboard/tests/test-master-spec-synthesis.sh scaffold-onboard/tests/test-render.sh
git commit -m "refactor(scaffold-onboard)!: SS-3 remove deterministic MASTER-SPEC transcription (synthesis-only)"
```

---

## Task 8: Rewrite the per-phase loop in `onboarding-project` SKILL (author records, not sections)

**Files:**
- Modify: `scaffold-onboard/skills/onboarding-project/SKILL.md` §3 (per-phase loop, lines ~61-71), §10 (helper list), §12 (anti-patterns)
- Verify: prose edit — checked by the behavioral harness in Task 10 + the grep guard below.

- [ ] **Step 1: Replace per-phase loop step 4**

In §3 "Per-phase loop", replace step 4 (currently: *"re-render the MASTER-SPEC section for this phase via `sf_master_spec_update_phase`…"*) with:

```markdown
4. After all questions in the phase are answered, **author the phase record**:
   compose a JSON object capturing the phase's reasoning — `decisions`,
   `rationale`, `alternatives_rejected`, `constraints`, `open_questions`,
   `critic_outcomes` (include only the keys that apply; content is free prose,
   NOT a copy of the raw answers). Write it with your Write tool to a temp file,
   then persist it:
   `sf state_write_phase_record <phase_id> <temp-file>`. This is reasoning work —
   it is authored by YOU in conversation, never slot-filled. The verbatim answers
   are already persisted (step 3); the record adds the *why*. Then surface a 3–5
   line recap **echoed from the record you just wrote** (no MASTER-SPEC file is
   rendered — none exists until close).
```

- [ ] **Step 2: Capture critic outcomes + user edits into the record**

In §5.2 step 5 (critic returns) and §3 step 6 (`accept | edit | append a note`), add:

```markdown
Before invoking the Phase 5/7 critic, write a concrete recap artifact:
`sf state_write_phase_artifact <phase_id> <artifact-path>`, then pass
`artifact_path=<artifact-path>` to `Skill(architect-critic:critiquing-spec)`.
When a critic challenge stands or the user edits/appends to the recap, fold that
into the phase record (re-author it and re-call `sf state_write_phase_record`),
so a later session inherits the resolved decision — never leave it only in
conversation.
```

- [ ] **Step 3: Add a run-reset at skill entry**

In §4 "Resume protocol" / skill entry (after lock acquire, before the per-phase loop), add:

```markdown
- **Reset the per-run tracker.** After acquiring the lock and determining mode,
  call `sf state_run_reset` once so `touched_this_run` reflects only phases
  (re)authored in THIS run — the reconcile hint for the close synthesis.
```

- [ ] **Step 4: Update §10 helper list + §12 anti-patterns**

In §10 "State" helpers, add `sf_state_write_phase_record`, `sf_state_read_phase_record`, `sf_state_write_phase_artifact`, `sf_state_run_reset`, `sf_state_phases_touched_this_run`, `sf_state_synthesis_digest`. In §10 "Rendering", remove `sf_render_master_spec_init` and `sf_master_spec_update_phase`. In §12 anti-patterns, replace any "render the section per phase" guidance; add: *"Do NOT transcribe raw answers into a templated MASTER-SPEC — there is no deterministic MASTER-SPEC renderer. The spec is synthesized once at close from the phase records + answers."*

- [ ] **Step 5: Grep guard**

Run: `grep -n "sf_master_spec_update_phase\|sf_master_spec_init\|sf_render_master_spec_init" scaffold-onboard/skills/onboarding-project/SKILL.md`
Expected: no matches (all transcription references removed).

- [ ] **Step 6: Commit**

```bash
git add scaffold-onboard/skills/onboarding-project/SKILL.md
git commit -m "feat(scaffold-onboard): SS-3 per-phase reasoning capture (author records, not sections)"
```

---

## Task 9: Rewrite the Phase-10 close ceremony (synthesis dispatch + inline fallback + backup)

**Files:**
- Modify: `scaffold-onboard/skills/onboarding-project/SKILL.md` §8 (Phase 10 close action, lines ~221-296)
- Verify: behavioral harness (Task 10).

- [ ] **Step 1: Insert MASTER-SPEC synthesis BEFORE the EXEC-SUMMARY step**

In §8, before the existing "Produce EXECUTIVE-SUMMARY.md" block, add a new MASTER-SPEC synthesis block. It must route every helper call through `sf` (the dispatcher-only runtime contract — no direct `source` from skill bodies):

````markdown
**Produce MASTER-SPEC.md (agent synthesis — no deterministic renderer).**

```bash
root="$(sf plugin_root)"
brief="${root}/templates/synthesis-briefs/MASTER-SPEC.brief.md"
master="$(sf resolve_output_path master_spec MASTER-SPEC.md)"
digest_file="$(mktemp "${TMPDIR:-/tmp}/sf-digest.XXXXXX")"
sf state_synthesis_digest > "$digest_file"
mode="first_author"; existing=""; touched=""; master_bak=""
if [[ -f "$master" ]]; then
  mode="reconcile"; existing="$master"
  touched="$(sf state_phases_touched_this_run | tr '\n' ' ' | sed 's/ $//')"
  master_bak="${master}.bak-$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cp "$master" "$master_bak"
fi
prompt="$(sf synth_master_spec_prompt "$brief" "$digest_file" "$master" "$mode" "$touched" "$existing")"
```

Then dispatch the synthesis agent with that prompt:

```text
Task(subagent_type="scaffold-onboard:synthesis-agent",
     description="Synthesize MASTER-SPEC",
     model="claude-sonnet-4-5",
     prompt="$prompt")
```

**Fallback (no dispatch available):** if you cannot dispatch a sub-agent (headless
/ no Task tool), DO NOT fall back to any deterministic renderer — there is none.
Instead, perform the synthesis yourself in this orchestration context: read the
SAME assembled `$prompt` (it embeds the brief + digest + mode) and author
`$master` directly with your Write tool, following the brief's guidance exactly.
The host (Claude Code or Codex) is itself a capable synthesizer because the brief
is a plugin asset. Only if the host runtime itself cannot write the file should
you stop and tell the user to re-run `/onboard` close later — state is fully
preserved, so nothing is lost.

Before close-depth critic or EXEC-SUMMARY, validate the synthesized spec:

```bash
sf spec_validate "$master"
```

If validation fails, surface stderr verbatim and stop; state is preserved for `/onboard --resume`.

After validation passes, run the close critic against `artifact_path="$master"`, then proceed to EXEC-SUMMARY.
````

- [ ] **Step 2: Keep the SS-2 EXEC-SUMMARY block, drop its `--fast`-only framing dependency**

Leave the existing EXEC-SUMMARY synthesis block (it reads from `$master`, which now exists). Confirm its helper calls also route through `sf` rather than direct `source` lines. No change needed beyond ordering (MASTER-SPEC first) and validation-before-consumption.

- [ ] **Step 3: Update the close summary text**

In the close summary heredoc, the line `MASTER-SPEC.md authored at <resolved_master_spec_path>.` stays accurate. Add a line when reconcile ran: `(reconciled — refreshed phases: <touched>; previous spec backed up to MASTER-SPEC.md.bak-<ts>.)`.

- [ ] **Step 4: Grep guard**

Run: `grep -n "sf_synth_master_spec_prompt\|sf_state_synthesis_digest\|synthesis-agent.*MASTER-SPEC\|Synthesize MASTER-SPEC" scaffold-onboard/skills/onboarding-project/SKILL.md`
Expected: matches present (the new block is wired).

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/skills/onboarding-project/SKILL.md
git commit -m "feat(scaffold-onboard): SS-3 close-ceremony MASTER-SPEC synthesis (dispatch + inline fallback + reconcile backup)"
```

---

## Task 10: Behavioral close-ceremony harness

**Files:**
- Modify: `scaffold-onboard/tests/test-master-spec-synthesis.sh`

This is the real OQ-style guard: extract the close-ceremony bash from SKILL.md §8 and **execute it under `set -euo pipefail`** with a faked synthesis-agent, proving the shell runs without unbound-variable / undefined-function abort and routes correctly. (Mirrors `tests/test-synthesis-dispatch.sh::_extract_section_bash`.)

- [ ] **Step 1: Write the failing test**

Add to `test-master-spec-synthesis.sh`:

```bash
SKILL="$ROOT/skills/onboarding-project/SKILL.md"

# Extract the first ```bash block that follows a heading containing <marker>.
_extract_bash_after() {
  local file="$1" marker="$2"
  awk -v m="$marker" '
    index($0, m) { armed=1 }
    armed && /^```bash/ { inb=1; next }
    inb && /^```/ { exit }
    inb { print }
  ' "$file"
}

test_close_master_spec_block_executes_clean() {
  echo "test_close_master_spec_block_executes_clean:"
  setup_tmp_repo
  _seed_min_state
  export CLAUDE_PLUGIN_ROOT="$ROOT"
  local block; block="$(_extract_bash_after "$SKILL" "Produce MASTER-SPEC.md")"
  [[ -n "$block" ]] || { FAIL=$((FAIL+1)); echo "  ✗ no MASTER-SPEC bash block found"; return; }
  # Execute the extracted setup block under strict mode; it must assemble the
  # prompt without abort. (The Task() dispatch line is prose, not bash.)
  if bash -c "set -euo pipefail; $block; [[ -n \"\$prompt\" ]] && [[ -n \"\$master\" ]]"; then
    PASS=$((PASS+1)); echo "  ✓ first-author close block runs clean + assembles prompt"
  else
    FAIL=$((FAIL+1)); echo "  ✗ close block aborted under set -euo pipefail"
  fi
}

test_close_block_reconcile_backs_up_existing() {
  echo "test_close_block_reconcile_backs_up_existing:"
  setup_tmp_repo
  _seed_min_state
  export CLAUDE_PLUGIN_ROOT="$ROOT"
  # Pre-existing MASTER-SPEC at the resolved (single-repo → cwd) path.
  printf '# todo-cli\n\n## Phase 1\nold\n' > "$TMP_DIR/repo/MASTER-SPEC.md"
  local block; block="$(_extract_bash_after "$SKILL" "Produce MASTER-SPEC.md")"
  bash -c "set -euo pipefail; $block; echo \"\$mode\" > $TMP_DIR/mode.out"
  assert_eq "reconcile mode detected" "reconcile" "$(cat "$TMP_DIR/mode.out")"
  # A .bak-* copy must now exist next to MASTER-SPEC.md.
  if ls "$TMP_DIR/repo/MASTER-SPEC.md.bak-"* >/dev/null 2>&1; then
    PASS=$((PASS+1)); echo "  ✓ existing spec backed up before reconcile"
  else
    FAIL=$((FAIL+1)); echo "  ✗ no backup created"
  fi
}
```

- [ ] **Step 2: Run tests**

Run: `bash scaffold-onboard/tests/test-master-spec-synthesis.sh`
Expected: PASS if Task 9's bash block sources `state.sh`/`synthesis.sh`/`routing.sh` and uses only defined helpers. If it FAILS with "unbound variable" or "command not found", fix the SKILL.md block (add the missing `source` line / helper) — do not weaken the test. This is the defect class SS-2 shipped a bug in.

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/tests/test-master-spec-synthesis.sh
git commit -m "test(scaffold-onboard): SS-3 behavioral close-ceremony harness (strict-mode execution + reconcile backup)"
```

---

## Task 11: Resumability + reconcile end-to-end integration tests

**Files:**
- Modify: `scaffold-onboard/tests/test-master-spec-synthesis.sh`

These prove the *data path* a real multi-session onboarding depends on, with a faked synthesis step (write the digest-derived MASTER-SPEC as the stub agent would).

- [ ] **Step 1: Write the failing tests**

Add to `test-master-spec-synthesis.sh`:

```bash
# Fake "synthesis": write a MASTER-SPEC that includes a marker per phase that has
# either an answer or a record in the digest, plus the required Executive Summary
# section. Stands in for the sub-agent so the integration path is deterministic.
_fake_synthesize_master_spec() {
  local out="$1" digest="$2"
  {
    echo "# $(sf_project_name)"
    echo ""
    echo "## Executive Summary"
    echo "Placeholder summary line."
    echo ""
    # Echo each phase heading the digest carried content for.
    printf '%s\n' "$digest" | awk '/^## Phase /{print}'
  } > "$out"
}

test_resumability_uses_persisted_records_across_sessions() {
  echo "test_resumability_uses_persisted_records_across_sessions:"
  setup_tmp_repo
  sf_state_init
  sf_state_run_reset
  # "Session A": phases 1-3 answered + records authored.
  sf_state_write_answer "1.1.1" "todo-cli — fast tasks"
  local r="$TMP_DIR/r.json"
  printf '{"decisions":"single JSON file"}' > "$r"; sf_state_write_phase_record 1 "$r"
  printf '{"decisions":"flat task schema"}' > "$r"; sf_state_write_phase_record 3 "$r"
  # "Session B": fresh process re-reads state from disk (no in-memory carryover).
  local digest; digest="$(sf_state_synthesis_digest)"
  printf '%s' "$digest" | grep -q "single JSON file" || { FAIL=$((FAIL+1)); echo "  ✗ phase-1 record lost across session"; return; }
  printf '%s' "$digest" | grep -q "flat task schema" || { FAIL=$((FAIL+1)); echo "  ✗ phase-3 record lost across session"; return; }
  PASS=$((PASS+1)); echo "  ✓ persisted phase records survive a session boundary"
}

test_reconcile_preserves_untouched_human_edit() {
  echo "test_reconcile_preserves_untouched_human_edit:"
  setup_tmp_repo
  sf_state_init
  # First author at close.
  sf_state_run_reset
  sf_state_write_answer "1.1.1" "todo-cli"
  local r="$TMP_DIR/r.json"; printf '{"decisions":"v1"}' > "$r"; sf_state_write_phase_record 1 "$r"
  local master="$TMP_DIR/repo/MASTER-SPEC.md"
  _fake_synthesize_master_spec "$master" "$(sf_state_synthesis_digest)"
  # Human edits an UNTOUCHED section directly in the file.
  printf '\n## Phase 8\nHAND-EDITED OPS NOTES — do not lose me.\n' >> "$master"
  # Enhancement re-run: only phase 1 re-answered this run.
  sf_state_run_reset
  printf '{"decisions":"v2"}' > "$r"; sf_state_write_phase_record 1 "$r"
  local touched; touched="$(sf_state_phases_touched_this_run | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "only phase 1 touched" "1" "$touched"
  # The reconcile prompt must carry the touched list AND point the agent at the
  # existing spec (which still holds the human edit). Assert the contract inputs.
  local prompt; prompt="$(sf_synth_master_spec_prompt "$BRIEF" "$(sf_state_synthesis_digest)" "$master" reconcile "$touched" "$master")"
  printf '%s' "$prompt" | grep -q "touched this run: 1" || { FAIL=$((FAIL+1)); echo "  ✗ touched list not in prompt"; return; }
  grep -q "HAND-EDITED OPS NOTES" "$master" || { FAIL=$((FAIL+1)); echo "  ✗ human edit already lost before synthesis"; return; }
  PASS=$((PASS+1)); echo "  ✓ reconcile feeds touched=1 + existing spec (human edit intact pre-synthesis)"
}
```

> **Note for the implementer:** these tests validate the *mechanical contract* feeding reconcile (touched list, digest, existing-spec path, backup) — the merge *judgment* itself is the agent's and is exercised by the W6 in-session smoke, not unit-assertable. Do not try to assert the merged output of a real LLM here.

- [ ] **Step 2: Run tests**

Run: `bash scaffold-onboard/tests/test-master-spec-synthesis.sh`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/tests/test-master-spec-synthesis.sh
git commit -m "test(scaffold-onboard): SS-3 resumability + reconcile contract integration tests"
```

---

## Task 12: Full suite, version bump, docs

**Files:**
- Modify: `scaffold-onboard/plugin.json`, Codex manifest, `scaffold-onboard/README.md` (version table), `CHANGELOG.md`
- Modify: `docs/agent-driven-program/SPEC-agent-driven-program.md` (ledger N3/#51 → in-progress/shipped)

- [ ] **Step 1: Run the FULL suite (not just named suites)**

Run: `bash scaffold-onboard/run-tests.sh`
Expected: all files PASS. Suites are slow (55–75s+ each) — run in the background with a generous timeout; do not assume a slow suite is hung. Distrust any "pre-existing failure" claim — investigate each red.

- [ ] **Step 2: Verify the no-determinism + dispatch guards specifically**

Run: `bash scaffold-onboard/run-tests.sh tests/test-master-spec-synthesis.sh tests/test-phase-records.sh tests/test-synthesis-dispatch.sh`
Expected: PASS — confirms SS-2's dispatch guards still green alongside SS-3's.

- [ ] **Step 3: Bump versions (Claude + Codex parity)**

Bump `scaffold-onboard/plugin.json` version (minor: `0.5.0` → `0.6.0`) and the Codex manifest in lockstep (parity is enforced by `tests/test-codex-dual-publish.sh`). Update the README version table.

Run: `bash scaffold-onboard/run-tests.sh tests/test-codex-dual-publish.sh`
Expected: PASS.

- [ ] **Step 4: Changelog + SPEC ledger**

Add a CHANGELOG `## [Unreleased]` entry under **Changed**: *"scaffold-onboard: MASTER-SPEC is now agent-synthesized at onboarding close (no deterministic transcription); onboarding state captures per-phase reasoning; enhancement re-runs reconcile (SS-3, #51)."* In the program SPEC §6 ledger, move N3/#51 to in-progress (or CLOSED once merged).

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/plugin.json scaffold-onboard/README.md CHANGELOG.md docs/agent-driven-program/SPEC-agent-driven-program.md
# (+ the Codex manifest path)
git commit -m "release(scaffold-onboard): SS-3 v0.6.0 — agent-synthesized resumable onboarding (#51)"
```

---

## Post-implementation (handled by the orchestrator, not a task)

- **W6 in-session smoke:** run one real `/onboard` close in an interactive session to confirm the sub-agent dispatch path produces a coherent MASTER-SPEC end-to-end (the irreducible-prose part the harness can't prove). Capture it in the build report as supplementary evidence.
- **Bot review:** expect a Codex/CodeRabbit cycle; per the SS-1/SS-2 pattern, specifically probe the **upgrade input class** (legacy state, reconcile-over-human-edit) — that's where the last two sub-specs' builds shipped defects.
- **Release mechanics:** tag `scaffold-onboard-v0.6.0` on the merge commit, push tags.

---

## Self-Review (completed by plan author)

**Spec coverage:**
- §2.1 close-only synthesis → Task 9 (close ceremony), Task 7 (no per-phase render). ✓
- §2.2 enriched state schema → Tasks 1, 2, 4. ✓
- §2.3 main-agent capture + raw kept → Task 8 (skill authors record), Task 2 (records beside answers). ✓
- §2.4 reconcile → Task 6 (assembler reconcile mode), Task 9 (backup + touched hint), Task 11 (contract test). ✓
- §2.5 tool-agnostic brief, Claude dispatch only → Task 5 (no Claude-isms), Task 9 (Claude dispatch + inline fallback). ✓
- §2.6 no deterministic renderer / dispatch→inline→retry → Task 7 (removal + guard), Task 9 (fallback prose), Task 10 (strict-mode harness). ✓
- §2.7 legacy migration → Task 3, Task 11 resumability. ✓
- §5 verification (dispatch test, inline fallback, resumability, reconcile, legacy, no-det guard) → Tasks 10, 11, 7, 3. ✓
- §1 EXEC-SUMMARY boundary (MASTER-SPEC emits `## Executive Summary`) → Task 5 brief requires it; Task 9 keeps SS-2 step. ✓

**Placeholder scan:** No `TBD`/`TODO`/"add error handling" — every code/test step shows real content. The `(none）` glyph in the assembler is intentional fallback text.

**Type consistency:** helper names consistent across tasks (`sf_state_write_phase_record`, `sf_state_read_phase_record`, `sf_state_run_reset`, `sf_state_phases_touched_this_run`, `sf_state_synthesis_digest`, `sf_synth_master_spec_prompt`); the assembler arg order (`brief, digest, out, mode, touched, existing`) is identical in Tasks 6, 9, 11.

**Gap noted & accepted:** the *quality* of a real LLM merge in reconcile mode is not unit-asserted (irreducibly agentic) — covered by the W6 in-session smoke, explicitly flagged in Task 11.
