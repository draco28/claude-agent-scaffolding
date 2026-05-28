# scaffold-onboard v0.3 Synthesis Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace deterministic `{{placeholder}}` substitution with LLM sub-agent synthesis for all post-MASTER-SPEC artifacts (governance docs, roadmap, memory-bank + CLAUDE.md), keeping structure/routing/validation deterministic.

**Architecture:** Two layers with a hard seam. Deterministic bash (`lib/synthesis.sh`) owns artifact selection, routing, structural-contract validation, ID validation, ledger assembly, the `--fast` escape, and re-gen semantics. A registered `scaffold-onboard:synthesis-agent` synthesizes content per a per-doc brief, dispatched in dependency waves by the three derivation skills, returning a compact ID ledger threaded into downstream briefs.

**Tech Stack:** Bash 3.2 (macOS-portable), `jq`, `awk`; Claude Code `Task`/Agent tool for dispatch; existing scaffold-onboard libs (`render.sh`, `docs.sh`, `memory-bank.sh`, `roadmap.sh`, `routing.sh`, `state.sh`).

**Source spec:** `docs/SPEC-scaffold-onboard-v03-synthesis.md` (decisions D1–D6 in §3).

**Branch & release:** Work on a feature branch `feat/scaffold-onboard-v03-synthesis` off current `main` (which already carries the unpushed design commit `d0adfb4`). At the end, bundle everything and push `main` once (per the user's "implement + release together" instruction).

---

## File Structure

**Create:**
- `scaffold-onboard/lib/synthesis.sh` — synthesis orchestration helpers (one responsibility: the deterministic half of the synthesis loop).
- `scaffold-onboard/agents/synthesis-agent.md` — `scaffold-onboard:synthesis-agent` registration + full inline behavioral contract (no separate skill; this agent has no standalone use).
- `scaffold-onboard/templates/synthesis-briefs/*.brief.md` — one brief per synthesizable artifact (PRD, SRS, BACKLOG, PROJECT_PLAN, ADR-0001, the 9 `--full` docs, ROADMAP-slice, and the 8 derived memory-bank files + CLAUDE.md).
- `scaffold-onboard/tests/test-synthesis.sh` — unit tests for every `lib/synthesis.sh` helper + the project_name fix.

**Modify:**
- `scaffold-onboard/lib/state.sh` — add shared `sf_project_name` helper.
- `scaffold-onboard/lib/render.sh:140-147`, `lib/docs.sh:13-20`, `lib/memory-bank.sh:130-138` — replace the three `${raw_pitch%% — *}` blocks with `sf_project_name`.
- `scaffold-onboard/templates/onboarding-questions/phases.yaml` — add question `1.1.4` (explicit short project name).
- `scaffold-onboard/lib/docs.sh`, `lib/roadmap.sh`, `lib/memory-bank.sh` — add the synthesize-vs-`--fast` branch (call into `lib/synthesis.sh`).
- `scaffold-onboard/skills/scaffolding-governance-docs/SKILL.md`, `skills/planning-project-roadmap/SKILL.md`, `skills/scaffolding-memory-bank/SKILL.md` — add the wave-dispatch orchestration block.
- `scaffold-onboard/.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` — version `0.2.3 → 0.3.0`.
- `scaffold-onboard/CHANGELOG.md`, root `README.md` — v0.3.0 entry + table/version notes.
- `scaffold-onboard/tests/test-docs.sh` — seed sets `1.1.4`; keep existing assertions green.

---

## Phase 0 — Deterministic core (TDD)

### Task 1: `sf_project_name` helper + fix the three em-dash sites

**Files:**
- Modify: `scaffold-onboard/lib/state.sh` (add helper near other readers)
- Modify: `scaffold-onboard/lib/render.sh:140-147`, `lib/docs.sh:13-20`, `lib/memory-bank.sh:130-138`
- Modify: `scaffold-onboard/templates/onboarding-questions/phases.yaml` (after question `1.1.3`)
- Modify: `scaffold-onboard/tests/test-docs.sh:13-31` (seed sets `1.1.4`)
- Test: `scaffold-onboard/tests/test-synthesis.sh`

- [ ] **Step 1: Write the failing test** (create `tests/test-synthesis.sh` with harness header + first test)

```bash
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/synthesis.sh"
PLUGIN_ROOT="$HERE/.."
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

test_project_name_prefers_explicit_answer() {
  echo "test_project_name_prefers_explicit_answer:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.1.1" "Acme — the — multi — dash — pitch"
  sf_state_write_answer "1.1.4" "Acme"
  assert_eq "explicit name wins" "Acme" "$(sf_project_name)"
}

test_project_name_no_emdash_truncation_fallback() {
  echo "test_project_name_no_emdash_truncation_fallback:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.1.1" "Acme — a — pitch — with — dashes"
  # 1.1.4 absent → must NOT return "Acme" via em-dash split; falls back to basename
  local got; got="$(sf_project_name)"
  assert_eq "fallback is basename, not em-dash prefix" "$(basename "$PWD")" "$got"
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scaffold-onboard/tests/test-synthesis.sh`
Expected: FAIL — `sf_project_name: command not found`.

- [ ] **Step 3: Add `sf_project_name` to `lib/state.sh`**

```bash
# Resolve a clean project name for titles/paths. Prefers the explicit onboarding
# answer 1.1.4; falls back to the cwd basename. Never truncates the pitch on
# em-dash (the v0.2.x bug that produced garbage H1 titles).
sf_project_name() {
  local explicit
  explicit="$(sf_state_read_answer 1.1.4 2>/dev/null || echo null)"
  if [[ -n "$explicit" && "$explicit" != "null" ]]; then
    printf '%s\n' "$explicit"
    return 0
  fi
  basename "$PWD"
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash scaffold-onboard/tests/test-synthesis.sh`
Expected: PASS (both project_name tests).

- [ ] **Step 5: Replace the three em-dash sites**

In `lib/render.sh:140-147`, replace the `raw_pitch` block + `args+=("project_name=$_project_name")` with:
```bash
  args+=("project_name=$(sf_project_name)")
```
In `lib/docs.sh:13-20`, replace the `raw_pitch` block + `args+=("project_name=$_project_name")` with the same one-liner.
In `lib/memory-bank.sh:130-141`, replace the `raw_oneliner` block + `args+=("project_name=$project_name")` with:
```bash
  local args=()
  args+=("project_name=$(sf_project_name)")
  args+=("ts=$ts")
```

- [ ] **Step 6: Add question 1.1.4 to `phases.yaml`** (after the `1.1.3` block, same indentation)

```yaml
          - id: "1.1.4"
            text: "Short project name (used for document titles and paths)?"
            required: true
```

- [ ] **Step 7: Update `tests/test-docs.sh` seed** — add after line 17 (`sf_state_write_answer "1.1.1" ...`):

```bash
  sf_state_write_answer "1.1.4" "test-proj"
```

- [ ] **Step 8: Run all affected suites**

Run: `bash scaffold-onboard/tests/test-synthesis.sh && bash scaffold-onboard/tests/test-docs.sh`
Expected: PASS, including existing `test_prd_content` (title `test-proj`, pitch text still present).

- [ ] **Step 9: Commit**

```bash
git add scaffold-onboard/lib/state.sh scaffold-onboard/lib/render.sh scaffold-onboard/lib/docs.sh scaffold-onboard/lib/memory-bank.sh scaffold-onboard/templates/onboarding-questions/phases.yaml scaffold-onboard/tests/test-synthesis.sh scaffold-onboard/tests/test-docs.sh
git commit -m "fix(scaffold-onboard): project_name em-dash truncation (#16); add sf_project_name + 1.1.4 capture"
```

---

### Task 2: `lib/synthesis.sh` skeleton + `sf_synth_enabled`

**Files:**
- Create: `scaffold-onboard/lib/synthesis.sh`
- Test: `scaffold-onboard/tests/test-synthesis.sh`

- [ ] **Step 1: Write the failing test**

```bash
test_synth_enabled_default_on() {
  echo "test_synth_enabled_default_on:"
  unset SF_SYNTH_FAST 2>/dev/null || true
  assert_eq "default is synthesize" "synthesize" "$(sf_synth_mode)"
}
test_synth_enabled_fast_flag() {
  echo "test_synth_enabled_fast_flag:"
  SF_SYNTH_FAST=1 assert_eq "--fast forces deterministic" "fast" "$(SF_SYNTH_FAST=1 sf_synth_mode)"
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scaffold-onboard/tests/test-synthesis.sh`
Expected: FAIL — `sf_synth_mode: command not found`.

- [ ] **Step 3: Create `lib/synthesis.sh` with the gate**

```bash
#!/usr/bin/env bash
# scaffold-onboard/lib/synthesis.sh
# Deterministic half of the LLM-synthesis loop (SPEC v0.3 §4-§9):
# brief assembly, ID validation, ledger merge, --fast gate, coverage rollup.
# The dispatch (Task tool) is driven by the derivation SKILL bodies, not here.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Resolve synthesize-vs-deterministic. Callers set SF_SYNTH_FAST=1 for --fast.
# Echoes "fast" or "synthesize".
sf_synth_mode() {
  if [[ "${SF_SYNTH_FAST:-0}" == "1" ]]; then
    echo "fast"
  else
    echo "synthesize"
  fi
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash scaffold-onboard/tests/test-synthesis.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/synthesis.sh scaffold-onboard/tests/test-synthesis.sh
git commit -m "feat(scaffold-onboard): synthesis.sh skeleton + sf_synth_mode (--fast gate)"
```

---

### Task 3: Brief frontmatter validator + field reader

**Files:**
- Modify: `scaffold-onboard/lib/synthesis.sh`
- Test: `scaffold-onboard/tests/test-synthesis.sh`

Brief frontmatter is YAML-ish but parsed with a minimal line reader (no YAML dep, bash 3.2). Required keys: `doc`, `routes_to`, `wave`, `required_sections` (list), `mints` (list, may be empty `[]`), `consumes` (list, may be empty `[]`), `model`.

- [ ] **Step 1: Write the failing test**

```bash
_write_sample_brief() {
  cat > "$1" <<'EOF'
---
doc: SRS
routes_to: srs
wave: 2
required_sections:
  - "Functional Requirements"
  - "Non-Functional Requirements"
  - "Traceability"
mints: [FR, NFR]
consumes: [UC]
model: opus
---
## Synthesis guidance
Derive FRs from PRD use cases.
EOF
}
test_brief_field_scalar() {
  echo "test_brief_field_scalar:"
  setup_tmp_repo
  _write_sample_brief ./b.brief.md
  assert_eq "routes_to" "srs" "$(sf_synth_brief_field ./b.brief.md routes_to)"
  assert_eq "wave" "2" "$(sf_synth_brief_field ./b.brief.md wave)"
  assert_eq "model" "opus" "$(sf_synth_brief_field ./b.brief.md model)"
}
test_brief_required_sections_list() {
  echo "test_brief_required_sections_list:"
  setup_tmp_repo
  _write_sample_brief ./b.brief.md
  local got; got="$(sf_synth_brief_list ./b.brief.md required_sections | tr '\n' '|')"
  assert_eq "sections" "Functional Requirements|Non-Functional Requirements|Traceability|" "$got"
}
test_brief_validate_ok() {
  echo "test_brief_validate_ok:"
  setup_tmp_repo
  _write_sample_brief ./b.brief.md
  if sf_synth_brief_validate ./b.brief.md; then echo "  ✓ valid"; PASS=$((PASS+1)); else echo "  ✗"; FAIL=$((FAIL+1)); fi
}
test_brief_validate_missing_key() {
  echo "test_brief_validate_missing_key:"
  setup_tmp_repo
  printf -- '---\ndoc: X\n---\nbody\n' > ./bad.brief.md
  if sf_synth_brief_validate ./bad.brief.md 2>/dev/null; then echo "  ✗ should fail"; FAIL=$((FAIL+1)); else echo "  ✓ rejected"; PASS=$((PASS+1)); fi
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scaffold-onboard/tests/test-synthesis.sh`
Expected: FAIL — `sf_synth_brief_field: command not found`.

- [ ] **Step 3: Implement in `lib/synthesis.sh`**

```bash
# Extract the YAML frontmatter block (between the first two '---' lines).
_sf_synth_frontmatter() {
  awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f{print}' "$1"
}

# Read a scalar frontmatter field. Echoes the value (quotes stripped) or empty.
sf_synth_brief_field() {
  local file="$1" key="$2"
  _sf_synth_frontmatter "$file" | awk -v k="$key" '
    $0 ~ "^"k":" { sub("^"k":[ \t]*", ""); gsub(/^"|"$/, ""); print; exit }'
}

# Read a list field. Supports inline "[a, b]" and block "- item" forms.
# Echoes one item per line (quotes/brackets stripped).
sf_synth_brief_list() {
  local file="$1" key="$2"
  _sf_synth_frontmatter "$file" | awk -v k="$key" '
    $0 ~ "^"k":" {
      rest=$0; sub("^"k":[ \t]*", "", rest)
      if (rest ~ /^\[/) {                      # inline form
        gsub(/^\[|\]$/, "", rest); n=split(rest, a, ",")
        for (i=1;i<=n;i++){ gsub(/^[ \t]+|[ \t]+$/,"",a[i]); gsub(/^"|"$/,"",a[i]); if(a[i]!="") print a[i] }
        exit
      }
      blk=1; next
    }
    blk && /^[ \t]*-[ \t]+/ { line=$0; sub(/^[ \t]*-[ \t]+/,"",line); gsub(/^"|"$/,"",line); print line; next }
    blk && /^[^ \t-]/ { exit }'
}

# Validate a brief has all required frontmatter keys. Returns 1 + logs on miss.
sf_synth_brief_validate() {
  local file="$1" k
  for k in doc routes_to wave model; do
    if [[ -z "$(sf_synth_brief_field "$file" "$k")" ]]; then
      sf_log_error "brief $file: missing required key '$k'"; return 1
    fi
  done
  if [[ -z "$(sf_synth_brief_list "$file" required_sections)" ]]; then
    sf_log_error "brief $file: required_sections is empty"; return 1
  fi
  return 0
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `bash scaffold-onboard/tests/test-synthesis.sh`
Expected: PASS (4 brief tests).

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/synthesis.sh scaffold-onboard/tests/test-synthesis.sh
git commit -m "feat(scaffold-onboard): brief frontmatter reader + validator"
```

---

### Task 4: Ledger merge

**Files:** Modify `lib/synthesis.sh`; Test `tests/test-synthesis.sh`.

The ledger is a JSON object: `{"use_cases":[{"id","title"}],"frs":[{"id","title","traces_uc"}],"nfrs":[...],"backlog":[...]}`. Merge folds a sub-agent's returned `ids_minted` into the running ledger (concatenating each family's array).

- [ ] **Step 1: Write the failing test**

```bash
test_ledger_merge_concats_families() {
  echo "test_ledger_merge_concats_families:"
  local base='{"use_cases":[{"id":"UC-1","title":"a"}],"frs":[],"nfrs":[],"backlog":[]}'
  local add='{"frs":[{"id":"FR-1","title":"f","traces_uc":["UC-1"]}]}'
  local out; out="$(sf_synth_ledger_merge "$base" "$add")"
  assert_eq "uc kept"  "UC-1" "$(printf '%s' "$out" | jq -r '.use_cases[0].id')"
  assert_eq "fr added" "FR-1" "$(printf '%s' "$out" | jq -r '.frs[0].id')"
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `bash scaffold-onboard/tests/test-synthesis.sh`
Expected: FAIL — `sf_synth_ledger_merge: command not found`.

- [ ] **Step 3: Implement**

```bash
# Empty ledger literal.
sf_synth_ledger_empty() { echo '{"use_cases":[],"frs":[],"nfrs":[],"backlog":[]}'; }

# Merge a returned ids_minted object into the running ledger (array concat per family).
sf_synth_ledger_merge() {
  local ledger="$1" add="$2"
  printf '%s\n%s\n' "$ledger" "$add" | jq -s '
    .[0] as $l | .[1] as $a
    | {
        use_cases: (($l.use_cases // []) + ($a.use_cases // [])),
        frs:       (($l.frs       // []) + ($a.frs       // [])),
        nfrs:      (($l.nfrs      // []) + ($a.nfrs      // [])),
        backlog:   (($l.backlog   // []) + ($a.backlog   // []))
      }'
}
```

- [ ] **Step 4: Run to verify it passes** — Run: `bash scaffold-onboard/tests/test-synthesis.sh` → PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/synthesis.sh scaffold-onboard/tests/test-synthesis.sh
git commit -m "feat(scaffold-onboard): synthesis ID-ledger merge"
```

---

### Task 5: ID validation + fill-in-marker scan

**Files:** Modify `lib/synthesis.sh`; Test `tests/test-synthesis.sh`.

Two checks against a synthesized doc: (a) every cited ID (passed as a space-separated list) exists in the ledger; (b) no fill-in markers (`*(...)*` or `TODO: `) remain in the file.

- [ ] **Step 1: Write the failing test**

```bash
test_validate_cited_ids_present() {
  echo "test_validate_cited_ids_present:"
  local led='{"use_cases":[{"id":"UC-1"}],"frs":[{"id":"FR-1"}],"nfrs":[],"backlog":[]}'
  if sf_synth_validate_cited "$led" "UC-1 FR-1"; then echo "  ✓"; PASS=$((PASS+1)); else echo "  ✗"; FAIL=$((FAIL+1)); fi
}
test_validate_cited_ids_missing() {
  echo "test_validate_cited_ids_missing:"
  local led='{"use_cases":[{"id":"UC-1"}],"frs":[],"nfrs":[],"backlog":[]}'
  if sf_synth_validate_cited "$led" "FR-9" 2>/dev/null; then echo "  ✗ should fail"; FAIL=$((FAIL+1)); else echo "  ✓ rejected"; PASS=$((PASS+1)); fi
}
test_no_fillin_markers_pass_and_fail() {
  echo "test_no_fillin_markers_pass_and_fail:"
  setup_tmp_repo
  printf '# Doc\nReal content.\n' > ./good.md
  printf '# Doc\n1. *(steps in order)*\n' > ./bad.md
  if sf_synth_assert_no_markers ./good.md; then echo "  ✓ clean ok"; PASS=$((PASS+1)); else echo "  ✗"; FAIL=$((FAIL+1)); fi
  if sf_synth_assert_no_markers ./bad.md 2>/dev/null; then echo "  ✗ should fail"; FAIL=$((FAIL+1)); else echo "  ✓ marker caught"; PASS=$((PASS+1)); fi
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (`sf_synth_validate_cited: command not found`).

- [ ] **Step 3: Implement**

```bash
# Assert every space-separated cited ID exists in the ledger's id sets.
sf_synth_validate_cited() {
  local ledger="$1" cited="$2" id
  local known
  known="$(printf '%s' "$ledger" | jq -r '[.use_cases[],.frs[],.nfrs[],.backlog[]] | .[].id')"
  for id in $cited; do
    if ! printf '%s\n' "$known" | grep -qxF "$id"; then
      sf_log_error "cited id '$id' not found in ledger"; return 1
    fi
  done
  return 0
}

# Reject leftover fill-in markers in a synthesized doc.
sf_synth_assert_no_markers() {
  local file="$1"
  if grep -nE '\*\([^)]*\)\*|TODO: ' "$file" >/dev/null 2>&1; then
    sf_log_error "fill-in markers remain in $file"; return 1
  fi
  return 0
}

# Assert each required section heading from a brief exists in the doc.
sf_synth_assert_sections() {
  local brief="$1" doc="$2" sec
  while IFS= read -r sec; do
    [[ -z "$sec" ]] && continue
    if ! grep -qF "$sec" "$doc"; then
      sf_log_error "required section '$sec' missing from $doc"; return 1
    fi
  done < <(sf_synth_brief_list "$brief" required_sections)
  return 0
}
```

- [ ] **Step 4: Run to verify it passes** — Run: `bash scaffold-onboard/tests/test-synthesis.sh` → PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/synthesis.sh scaffold-onboard/tests/test-synthesis.sh
git commit -m "feat(scaffold-onboard): ID-citation + section + no-marker validators"
```

---

### Task 6: Brief assembly (sub-agent prompt builder)

**Files:** Modify `lib/synthesis.sh`; Test `tests/test-synthesis.sh`.

`sf_synth_brief_assemble <brief-file> <ledger-json> <output-abs-path> <master-spec-abs> <exec-summary-abs>` echoes the full prompt text handed to the synthesis sub-agent: the brief body + required-section contract + the relevant ledger slice (only `consumes` families) + the four source/target paths + the ID-mint instructions.

- [ ] **Step 1: Write the failing test**

```bash
test_brief_assemble_includes_paths_and_ledger_slice() {
  echo "test_brief_assemble_includes_paths_and_ledger_slice:"
  setup_tmp_repo
  _write_sample_brief ./b.brief.md   # consumes: [UC], mints: [FR,NFR]
  local led='{"use_cases":[{"id":"UC-1","title":"login"}],"frs":[{"id":"FR-9"}],"nfrs":[],"backlog":[]}'
  local out; out="$(sf_synth_brief_assemble ./b.brief.md "$led" /tmp/SRS.md /tmp/MASTER-SPEC.md /tmp/EXECUTIVE-SUMMARY.md)"
  printf '%s' "$out" | grep -q "/tmp/SRS.md"            && echo "  ✓ output path"   && PASS=$((PASS+1)) || { echo "  ✗"; FAIL=$((FAIL+1)); }
  printf '%s' "$out" | grep -q "UC-1"                   && echo "  ✓ consumed UC"   && PASS=$((PASS+1)) || { echo "  ✗"; FAIL=$((FAIL+1)); }
  printf '%s' "$out" | grep -q "FR-9"                   && { echo "  ✗ leaked non-consumed family"; FAIL=$((FAIL+1)); } || { echo "  ✓ FR slice excluded"; PASS=$((PASS+1)); }
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (`sf_synth_brief_assemble: command not found`).

- [ ] **Step 3: Implement**

```bash
# Map a family token (UC/FR/NFR/BACKLOG) to its ledger array key.
_sf_synth_family_key() {
  case "$1" in
    UC) echo use_cases ;; FR) echo frs ;; NFR) echo nfrs ;; BACKLOG) echo backlog ;;
    *) echo "" ;;
  esac
}

sf_synth_brief_assemble() {
  local brief="$1" ledger="$2" out_path="$3" master="$4" exec_summary="$5"
  local body slice fam key
  body="$(awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{f=0;skip=1;next} skip{print}' "$brief")"

  # Build the consumed-ledger slice (only families this doc consumes).
  slice="$(sf_synth_ledger_empty)"
  while IFS= read -r fam; do
    [[ -z "$fam" ]] && continue
    key="$(_sf_synth_family_key "$fam")"; [[ -z "$key" ]] && continue
    slice="$(printf '%s' "$ledger" | jq --arg k "$key" '{($k): (.[$k] // [])}' \
            | { read -r s; sf_synth_ledger_merge "$slice" "$s"; })"
  done < <(sf_synth_brief_list "$brief" consumes)

  cat <<EOF
You are synthesizing one artifact for the project. Read both source documents in full first:
- MASTER-SPEC: $master
- EXECUTIVE-SUMMARY: $exec_summary

Write the artifact to: $out_path

Required sections (must all appear, in this order):
$(sf_synth_brief_list "$brief" required_sections | sed 's/^/- /')

IDs you must MINT (format below) and/or CITE from the provided ledger:
- mints: $(sf_synth_brief_list "$brief" mints | tr '\n' ' ')
- consumes (cite only these IDs; they already exist): $(sf_synth_brief_list "$brief" consumes | tr '\n' ' ')

Provided ID ledger slice (cite IDs from here; do not invent IDs in consumed families):
$slice

Synthesis guidance:
$body

Hard rules: no fill-in markers (no "*(...)*", no "TODO:"); every required section has real content; return the ID-ledger JSON described in your agent contract.
EOF
}
```

- [ ] **Step 4: Run to verify it passes** — Run: `bash scaffold-onboard/tests/test-synthesis.sh` → PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/synthesis.sh scaffold-onboard/tests/test-synthesis.sh
git commit -m "feat(scaffold-onboard): brief assembly with consumed-ledger slicing"
```

---

### Task 7: Coverage rollup (#14 carry-over)

**Files:** Modify `lib/synthesis.sh`; Test `tests/test-synthesis.sh`.

`sf_synth_coverage_report <ledger-json> <covered-ids-newline-list>` prints, per family, which IDs are covered vs unassigned.

- [ ] **Step 1: Write the failing test**

```bash
test_coverage_report_flags_unassigned() {
  echo "test_coverage_report_flags_unassigned:"
  local led='{"use_cases":[],"frs":[{"id":"FR-1"},{"id":"FR-2"}],"nfrs":[{"id":"NFR-1"}],"backlog":[]}'
  local covered=$'FR-1\nNFR-1'
  local out; out="$(sf_synth_coverage_report "$led" "$covered")"
  printf '%s' "$out" | grep -q "FR-2: UNASSIGNED" && echo "  ✓ unassigned flagged" && PASS=$((PASS+1)) || { echo "  ✗"; FAIL=$((FAIL+1)); }
  printf '%s' "$out" | grep -q "FR-1: covered"     && echo "  ✓ covered shown"     && PASS=$((PASS+1)) || { echo "  ✗"; FAIL=$((FAIL+1)); }
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL.

- [ ] **Step 3: Implement**

```bash
sf_synth_coverage_report() {
  local ledger="$1" covered="$2" id
  echo "## Requirement coverage"
  for id in $(printf '%s' "$ledger" | jq -r '[.frs[],.nfrs[]] | .[].id'); do
    if printf '%s\n' "$covered" | grep -qxF "$id"; then
      echo "- $id: covered"
    else
      echo "- $id: UNASSIGNED"
    fi
  done
}
```

- [ ] **Step 4: Run to verify it passes** — Run: `bash scaffold-onboard/tests/test-synthesis.sh` → PASS.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/synthesis.sh scaffold-onboard/tests/test-synthesis.sh
git commit -m "feat(scaffold-onboard): requirement coverage rollup (#14 carry-over)"
```

---

## Phase 1 — Synthesis agent + briefs

### Task 8: Register `scaffold-onboard:synthesis-agent`

**Files:** Create `scaffold-onboard/agents/synthesis-agent.md`.

- [ ] **Step 1: Write the agent file** (mirrors `scaffold-dev/agents/implementer-agent.md`; contract is inline since there's no standalone-skill use)

```markdown
---
name: synthesis-agent
description: Synthesize one post-MASTER-SPEC artifact (governance doc, roadmap-slice, memory-bank file, or CLAUDE.md) from MASTER-SPEC.md + EXECUTIVE-SUMMARY.md per a synthesis brief passed in the invocation prompt. Reads the two sources + the brief, writes the artifact to the given absolute path honoring the required-section contract, mints/cites IDs from the provided ledger slice, never emits fill-in markers, and returns a compact ID-ledger JSON. NEVER runs git and NEVER invokes Task (no subagent nesting).
tools: Read, Write, Grep, Glob
model: inherit
---

You synthesize exactly one artifact. The invocation prompt is your brief: it names the two source documents, the output path, the required sections, the IDs to mint/cite, and the provided ledger slice.

## Binding rules
- Read MASTER-SPEC.md and EXECUTIVE-SUMMARY.md in full before writing.
- Write ONLY the named output path. Produce every required section with real, specific content.
- Mint IDs only in the families listed under `mints`, using the stated format (e.g. `FR-1`, `NFR-1`, `UC-1`, `BACKLOG-1`), numbered from 1.
- Cite IDs only from the provided ledger slice; never invent IDs in a consumed family.
- NEVER leave fill-in markers (`*(...)*`, `TODO:`), placeholder sprints, or generic backlog items.
- You have no Bash, no git, no Task. You cannot dispatch further agents.

## Return contract (your final message MUST end with this JSON)

```json
{"mode":"complete","output_path":"<abs>","ids_minted":{"use_cases":[],"frs":[],"nfrs":[],"backlog":[]},"ids_cited":["..."],"summary":"<one line>"}
```

On failure to satisfy the brief:

```json
{"mode":"failed","reason":"<why>","partial_output_path":null}
```

`ids_minted` families omit-or-empty those you didn't mint. `traces_uc` (on frs/nfrs) and `traces_fr` (on backlog) arrays are required where the brief says to trace.
```

- [ ] **Step 2: Validate JSON-free markdown + frontmatter keys**

Run: `head -6 scaffold-onboard/agents/synthesis-agent.md`
Expected: frontmatter has `name`, `description`, `tools: Read, Write, Grep, Glob`, `model`.

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/agents/synthesis-agent.md
git commit -m "feat(scaffold-onboard): register synthesis-agent (Read/Write/Grep/Glob, no Task/git)"
```

---

### Task 9: Author the brief format + 5 minimal-doc briefs

**Files:** Create `scaffold-onboard/templates/synthesis-briefs/{PRD,SRS,BACKLOG,PROJECT_PLAN,ADR-0001}.brief.md`.

**Migration procedure (apply per doc):** read the matching `templates/docs-minimal/<DOC>.md.tmpl`, copy its `##` headings verbatim into `required_sections` (preserving order), set `routes_to` to the logical name from `lib/routing.sh` (`prd`/`srs`/`backlog`/`project_plan`/`product_adrs`), set `wave`/`mints`/`consumes`/`model` per the table, then write synthesis guidance prose.

| Brief | routes_to | wave | mints | consumes | model |
|-------|-----------|------|-------|----------|-------|
| PRD | prd | 1 | UC | — | opus |
| SRS | srs | 2 | FR, NFR | UC | opus |
| BACKLOG | backlog | 3 | BACKLOG | UC, FR | sonnet |
| PROJECT_PLAN | project_plan | 4 | — | UC, FR, BACKLOG | sonnet |
| ADR-0001 | product_adrs | 4 | — | — | sonnet |

- [ ] **Step 1: Write `SRS.brief.md` (the #16-critical worked example, complete)**

```markdown
---
doc: SRS
routes_to: srs
wave: 2
required_sections:
  - "Functional Requirements"
  - "Non-Functional Requirements"
  - "Traceability"
mints: [FR, NFR]
consumes: [UC]
model: opus
---
## Synthesis guidance

Functional Requirements: derive each FR from a PRD **use case** (UC-N) in the
provided ledger slice. Every `FR-N` states a capability the system must DO and
MUST trace to ≥1 UC (`traces_uc`). Do NOT source FRs from implementation choices
(module boundaries, code style, ORM/API selection — those are design, not FRs).

Non-Functional Requirements: derive each `NFR-N` from a quality attribute —
latency/throughput budgets (MASTER-SPEC §5.3.2), determinism invariants (Phase 3),
security invariants (Phase 4), coverage floors / quality gates (Phase 9). Do NOT
source NFRs from devops/hosting/CI (Phase 8). Where an NFR is a slice's acceptance
bar, phrase it test-ably (e.g. "p95 < 200ms", "100× identical hash").

Traceability: render a table mapping each FR/NFR → the UC(s) it serves.
Number FR and NFR from 1. Cite only UC IDs present in the ledger slice.
```

- [ ] **Step 2: Write the other four minimal briefs** per the table + their `.tmpl` headings. PRD guidance: emit a `UC-1..UC-N` use-case set (not a single use case) covering the core loop + feature backlog + domain operations; each UC has actor, trigger, outcome. BACKLOG guidance: real, project-specific backlog items each tracing to FR/UC; no generic placeholders. PROJECT_PLAN guidance: real sprint breakdown grounded in the BACKLOG + roadmap intent; no `### Sprint 1 *(populate later)*`. ADR-0001 guidance: the standard "record architecture decisions" ADR with project-specific context.

- [ ] **Step 3: Validate every brief**

Run:
```bash
for b in scaffold-onboard/templates/synthesis-briefs/*.brief.md; do
  bash -c 'source scaffold-onboard/lib/synthesis.sh; sf_synth_brief_validate "$1"' _ "$b" || echo "INVALID: $b"
done
```
Expected: no `INVALID` lines.

- [ ] **Step 4: Commit**

```bash
git add scaffold-onboard/templates/synthesis-briefs/
git commit -m "feat(scaffold-onboard): minimal-doc synthesis briefs (PRD/SRS/BACKLOG/PROJECT_PLAN/ADR; #16 fix in SRS)"
```

---

### Task 10: Author the 9 `--full` briefs

**Files:** Create `synthesis-briefs/{RISK_REGISTER,THREAT_MODEL,TEST_STRATEGY,DEFINITION_OF_DONE,CUTOVER_PLAN,DEMO_RUNBOOK,EVALS_PLAN,MODEL_CARD,PROMPT_GOVERNANCE}.brief.md`.

All `wave: 4`, `consumes: [UC, FR, NFR, BACKLOG]` (cite as relevant), `mints: []`, `model: sonnet`, `routes_to`: `product_adrs` for RISK_REGISTER/THREAT_MODEL/TEST_STRATEGY/CUTOVER_PLAN/EVALS_PLAN/MODEL_CARD; `process_adrs` for DEFINITION_OF_DONE/DEMO_RUNBOOK/PROMPT_GOVERNANCE. `required_sections` copied from each `templates/docs-full/<DOC>.md.tmpl`. CUTOVER_PLAN guidance must explicitly produce ordered cutover + rollback steps with expected outcomes and a real stakeholder list (the markers #17 cited).

- [ ] **Step 1: Author all nine** following Task 9's migration procedure (headings from the `.tmpl`, prose guidance per doc).
- [ ] **Step 2: Validate** (rerun Task 9 Step 3 loop) → no `INVALID`.
- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/templates/synthesis-briefs/
git commit -m "feat(scaffold-onboard): --full synthesis briefs (9 docs)"
```

---

### Task 11: Author roadmap-slice + memory-bank + CLAUDE.md briefs

**Files:** Create `synthesis-briefs/{ROADMAP-slice,00-project-brief,01-product-context,02-system-patterns,03-code-patterns,04-tech-context,07-constraints,08-governance,index,CLAUDE}.brief.md`.

ROADMAP-slice: `wave: 4`, `routes_to: roadmap`, `consumes: [UC, FR, NFR, BACKLOG]`, `mints: []`; guidance = synthesize each slice's scope + `auto:`/`user:` demo criteria grounded in the spec, citing FR/NFR/BACKLOG IDs (lightweight mode: omit trace citations + warn). Memory-bank briefs: `routes_to: memory_bank`; `03-code-patterns` keeps the empty R2 mcrule section (seed heading only — do not synthesize rules). CLAUDE: `routes_to: claude_md`.

- [ ] **Step 1: Author the ten briefs** (headings from `templates/memory-bank/*.md.tmpl` and `templates/claude-md/CLAUDE.md.tmpl`).
- [ ] **Step 2: Validate** → no `INVALID`.
- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/templates/synthesis-briefs/
git commit -m "feat(scaffold-onboard): roadmap-slice + memory-bank + CLAUDE synthesis briefs"
```

---

## Phase 2 — Wire dispatch into the derivation skills

> The orchestrator is the skill-running session. Each skill gets a "Synthesis dispatch" section that: (1) checks `--fast` → if set, run today's deterministic path and stop; (2) else render skeletons + resolve paths via bash, then dispatch `scaffold-onboard:synthesis-agent` in the brief-declared wave order, collecting returned `ids_minted` into the ledger and threading it into downstream briefs; (3) after each artifact, run `sf_synth_assert_sections` + `sf_synth_assert_no_markers` + `sf_synth_validate_cited`; on failure, fall back to deterministic render for that artifact with a warning.

### Task 12: `/scaffold-docs` wiring + `--fast` branch in `docs.sh`

**Files:** Modify `scaffold-onboard/lib/docs.sh` (add `--fast` passthrough + a `sf_docs_synthesize` entry that lists the brief set in wave order), `skills/scaffolding-governance-docs/SKILL.md` (add the dispatch section).

- [ ] **Step 1: Add `--fast` parse + branch to `sf_docs_derive`** — extend the arg loop (`docs.sh:51-57`) with `--fast) export SF_SYNTH_FAST=1 ;;`. At the top of the body after arg parse:

```bash
  if [[ "$(sf_synth_mode)" == "fast" ]]; then
    : # fall through to the existing deterministic _write_or_skip path below
  fi
```
(The deterministic path is unchanged and serves as both `--fast` and the per-artifact fallback. Synthesis is driven from the SKILL body, which calls the brief-assembly helpers and dispatches agents, then writes via the agent; bash validates afterward.)

- [ ] **Step 2: Add the dispatch section to `scaffolding-governance-docs/SKILL.md`** (prose; insert after the existing derivation description). Required content:
  - Source `lib/synthesis.sh` + `lib/routing.sh`.
  - If `--fast`: call `sf_docs_derive --fast` and stop.
  - Else dispatch waves using `Task(subagent_type="scaffold-onboard:synthesis-agent", description=..., prompt=$(sf_synth_brief_assemble <brief> <ledger> <out_path> <master_abs> <execsummary_abs>))`, model per the brief's `model:` field (Opus for PRD/SRS, else Sonnet), in order: Wave1 PRD → Wave2 SRS → Wave3 BACKLOG → Wave4 (PROJECT_PLAN, ADR-0001, `--full` set, gated by Phase 9.3.1). After each return, `sf_synth_ledger_merge` the `ids_minted`; before dispatching a consumer, the ledger already holds its inputs.
  - After all waves: `sf_synth_coverage_report` printed to the user.
  - Per-artifact failure → fall back to `_write_or_skip` (deterministic) for that doc with a `sf_log_warn`.

- [ ] **Step 3: Test the deterministic path still works** (synthesis path is agent-driven, not unit-tested)

Run: `bash scaffold-onboard/tests/test-docs.sh`
Expected: PASS (the `--fast`/deterministic path is what the suite exercises).

- [ ] **Step 4: Commit**

```bash
git add scaffold-onboard/lib/docs.sh scaffold-onboard/skills/scaffolding-governance-docs/SKILL.md
git commit -m "feat(scaffold-onboard): wire /scaffold-docs synthesis waves + --fast"
```

---

### Task 13: `/plan-roadmap` wiring

**Files:** Modify `lib/roadmap.sh` (`--fast` passthrough), `skills/planning-project-roadmap/SKILL.md` (dispatch section).

- [ ] **Step 1: Add `--fast` handling** mirroring Task 12 Step 1 in the roadmap render entry.
- [ ] **Step 2: Add the dispatch section to `planning-project-roadmap/SKILL.md`:** wave-4 slice synthesis using the `ROADMAP-slice` brief; if `/scaffold-docs` ran first, load its ledger and require slices to cite FR/NFR/BACKLOG; in lightweight mode (no ledger), synthesize without trace citations and `sf_log_warn` per the existing two-sequence contract.
- [ ] **Step 3: Test** — Run: `bash scaffold-onboard/tests/test-roadmap.sh` → PASS (deterministic path intact).
- [ ] **Step 4: Commit**

```bash
git add scaffold-onboard/lib/roadmap.sh scaffold-onboard/skills/planning-project-roadmap/SKILL.md
git commit -m "feat(scaffold-onboard): wire /plan-roadmap slice synthesis"
```

---

### Task 14: `/scaffold-project` wiring

**Files:** Modify `lib/memory-bank.sh` (`--fast` passthrough), `skills/scaffolding-memory-bank/SKILL.md` (dispatch section).

- [ ] **Step 1: Add `--fast` handling** to `sf_memory_bank_derive` / `sf_claude_md_generate` callers.
- [ ] **Step 2: Add the dispatch section to `scaffolding-memory-bank/SKILL.md`:** wave-4 synthesis of the 8 derived memory-bank files + CLAUDE.md from sources + ledger; live files (`05`/`06`) + static `WORKFLOW.md` keep seed-once behavior; `03-code-patterns` keeps the empty R2 section.
- [ ] **Step 3: Test** — Run: `bash scaffold-onboard/tests/test-docs.sh` and any memory-bank suite → PASS.
- [ ] **Step 4: Commit**

```bash
git add scaffold-onboard/lib/memory-bank.sh scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md
git commit -m "feat(scaffold-onboard): wire /scaffold-project memory-bank + CLAUDE synthesis"
```

---

## Phase 3 — Gates, release, bundle

### Task 15: Full regression + brief-validation gate

- [ ] **Step 1: Run every suite**

```bash
bash scaffold-onboard/tests/test-synthesis.sh
bash scaffold-onboard/tests/test-state.sh
bash scaffold-onboard/tests/test-roadmap.sh
bash scaffold-onboard/tests/test-docs.sh
bash scaffold-onboard/tests/test-manifest-routing.sh
bash tests/test-codex-dual-publish.sh
```
Expected: all suites `0 failed`.

- [ ] **Step 2: Validate all briefs in CI form** — add to `tests/test-synthesis.sh` a loop asserting `sf_synth_brief_validate` passes for every `templates/synthesis-briefs/*.brief.md`, and re-run.

- [ ] **Step 3: `git diff --check`** → clean.

- [ ] **Step 4: Commit** (if Step 2 added a test)

```bash
git add scaffold-onboard/tests/test-synthesis.sh
git commit -m "test(scaffold-onboard): CI brief-validation sweep"
```

---

### Task 16: Version bump + docs

**Files:** `scaffold-onboard/.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `scaffold-onboard/CHANGELOG.md`, root `README.md`.

- [ ] **Step 1: Bump both manifests** `0.2.3 → 0.3.0`.
- [ ] **Step 2: CHANGELOG `## [0.3.0]` entry** — Added: LLM sub-agent synthesis layer (#17), `synthesis-agent`, synthesis briefs, `--fast` escape, coverage rollup; Fixed: SRS FR/NFR sourcing + PRD use-case set (#16), `project_name` em-dash bug; Changed: post-MASTER-SPEC derivation is synthesis-by-default.
- [ ] **Step 3: README** — scaffold-onboard row `v0.2.3 → v0.3.0`; layout version note; add "LLM synthesis (default; `--fast` for deterministic)" to the feature blurb.
- [ ] **Step 4: Validate JSON** — `jq . scaffold-onboard/.claude-plugin/plugin.json && jq . scaffold-onboard/.codex-plugin/plugin.json`.
- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/.claude-plugin/plugin.json scaffold-onboard/.codex-plugin/plugin.json scaffold-onboard/CHANGELOG.md README.md
git commit -m "release(scaffold-onboard): v0.3.0 — synthesis layer (#17, #16)"
```

---

### Task 17: Bundle + release

- [ ] **Step 1: Confirm branch state** — `git log --oneline main..HEAD` shows the Phase 0–3 commits; the design commit `d0adfb4` is already on `main`.
- [ ] **Step 2: Fast-forward merge to main** — `git checkout main && git merge --ff-only feat/scaffold-onboard-v03-synthesis`.
- [ ] **Step 3: Push once** — `git fetch origin && git push origin main` (this carries `d0adfb4` + all v0.3 work together, per the bundled-release instruction).
- [ ] **Step 4: Close #17 and #16** — `gh issue close 17 16 --comment "Shipped in scaffold-onboard v0.3.0 (synthesis layer). #16 resolved via the SRS/PRD briefs."` (or include `Closes #17` / `Closes #16` in the merge/release commit so the push auto-closes them).
- [ ] **Step 5: Delete the feature branch** — local `git branch -d feat/scaffold-onboard-v03-synthesis`; remote only if it was pushed.

---

## Self-review notes (author check, not a task)

- **Spec coverage:** D1 (all surfaces) → Tasks 9–14; D2 (skeleton+content) → briefs + validators; D3 (ledger waves) → Tasks 4/6 + 12; D4 (default-on + `--fast`) → Task 2 + 12–14; D5 (skip/`--regenerate`) → unchanged `_write_or_skip` reused; D6 (Sonnet/Opus) → brief `model:` + Task 12. #16 → SRS/PRD briefs. project_name bug → Task 1. Coverage rollup (#14) → Task 7.
- **No placeholders:** code-bearing steps carry full code; content tasks (briefs/skills) give the migration procedure + a complete worked example (SRS brief, agent contract) + per-doc tables — the concrete equivalent for prose artifacts.
- **Type/name consistency:** helper names used consistently — `sf_synth_mode`, `sf_synth_brief_{field,list,validate,assemble}`, `sf_synth_ledger_{empty,merge}`, `sf_synth_validate_cited`, `sf_synth_assert_{sections,no_markers}`, `sf_synth_coverage_report`, `sf_project_name`.
