# SS-2 — Synthesis Live & Verified + EXEC-SUMMARY + post-derivation review — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make scaffold-onboard's LLM-synthesis dispatch *actually execute end-to-end* on both `/scaffold-project` and `/scaffold-docs`, synthesize EXECUTIVE-SUMMARY from MASTER-SPEC with a single authoritative producer, add an advisory post-derivation review with a real disposition lifecycle, and add a **behavioral dispatch harness** so a broken dispatch can never merge green.

**Architecture:** The synthesis dispatch lives as prose in two SKILL sections (`scaffolding-memory-bank` §13, `scaffolding-governance-docs` §11) because bash cannot dispatch sub-agents. OQ-1 found those sections call lib helpers they never `source` → abort under the slash command's `set -u`. SS-2 (1) fixes the sourcing + replaces comment-only `# STOP` with real control-flow, (2) implements the phantom `sf_render_executive_summary` as a real deterministic renderer with a pinned MASTER-SPEC `## Executive Summary` parser contract + makes onboarding the single authoritative producer of EXEC-SUMMARY while `/scaffold-*` only consume-if-missing + staleness-warn, (3) adds a read-only `derivation-reviewer` agent whose findings are recorded + artifact-linked with a targeted-regenerate apply path, and (4) adds a behavioral harness that extracts the actual `bash` blocks from the SKILL sections, shims `Task()`, and runs them under `set -euo pipefail` with faked agent outputs.

**Tech Stack:** Bash 3.2 (macOS-portable, BSD awk/sed/cksum), markdown SKILL/agent/brief prose, the scaffold-onboard bash test harness (`tests/test-*.sh` + `run-tests.sh`). **scaffold-onboard only** — scaffold-dev untouched.

**Spec:** `docs/agent-driven-program/specs/SS-2-synthesis-live-and-verified.md` (design-locked + critique-hardened).

**Key files:**
- `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md` §13 (memory-bank dispatch)
- `scaffold-onboard/skills/scaffolding-governance-docs/SKILL.md` §11 (governance dispatch)
- `scaffold-onboard/skills/onboarding-project/SKILL.md` §8 (EXEC-SUMMARY producer) + `references/example-walkthrough.md:213` (phantom ref)
- `scaffold-onboard/lib/render.sh` (add `sf_render_executive_summary` + staleness helper)
- `scaffold-onboard/templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md` (new)
- `scaffold-onboard/agents/derivation-reviewer.md` (new)
- `scaffold-onboard/templates/master-spec/EXECUTIVE-SUMMARY.md.tmpl` (placeholders `{{project_name}}`, `{{executive_summary}}`, `{{project_class}}`, `{{created_date}}`)
- `scaffold-onboard/tests/test-synthesis-dispatch.sh` (new — behavioral harness + source-guard + parser-contract + staleness)

**Fixed strings/contracts (use verbatim):**
- MASTER-SPEC executive-summary heading: `## Executive Summary` (MASTER-SPEC.md.tmpl:13).
- EXEC-SUMMARY provenance trailer: `<!-- derived from MASTER-SPEC.md cksum:<sum> -->`.
- Review report path: `<bundle-dir>/derivation-review.md`.
- Logical names already supported by `sf_resolve_output_path`: `master_spec`, `executive_summary`, `memory_bank`, `claude_md`, `prd`, `srs`, `backlog`, `project_plan`, `product_adrs`, `process_adrs`.

## How to run the suite
```bash
bash scaffold-onboard/run-tests.sh                       # full (slow: 55-75s+/file)
bash scaffold-onboard/run-tests.sh tests/test-synthesis-dispatch.sh   # one file
bash scaffold-onboard/run-tests.sh tests/test-synthesis.sh
bash tests/test-codex-dual-publish.sh                    # release parity gate
```
Per `feedback_full_suite_when_verifying_subagents`: run the whole suite before declaring any task green.

---

## Task 1 (W1): Dispatch executability — source the libs + real STOP control-flow

**Files:**
- Modify: `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md` (§13.1, §13.2)
- Modify: `scaffold-onboard/skills/scaffolding-governance-docs/SKILL.md` (§11.1, §11.2)
- Test: `scaffold-onboard/tests/test-synthesis-dispatch.sh` (new — the source-guard test)

The dispatch/fallback/finalize bodies call helpers from libs the setup never sources. Memory-bank §13 calls `sf_memory_bank_derive`, `sf_claude_md_generate`, `sf_claude_settings_generate`, `sf_agents_md_generate`, `_memory_bank_args`, `_sf_mb_extract_preserve_zone`, `_sf_mb_reinject_preserve_zone` (all `lib/memory-bank.sh`) and `sf_render` (`lib/render.sh`) — but §13.1 sources only `synthesis.sh` + `routing.sh`. Governance §11 calls `sf_docs_derive` / `_write_or_skip` (`lib/docs.sh`) — §11.1 sources only `synthesis.sh` + `routing.sh`. The comment-only `# STOP` in both fast-path short-circuits doesn't exit.

- [ ] **Step 1: Write the failing source-guard test**

Create `scaffold-onboard/tests/test-synthesis-dispatch.sh`:

```bash
#!/usr/bin/env bash
# test-synthesis-dispatch.sh — SS-2: behavioral + structural guards for the
# synthesis dispatch prose. Catches the OQ-1 unsourced-helper class for real.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
ROOT="$HERE/.."
MB_SKILL="$ROOT/skills/scaffolding-memory-bank/SKILL.md"
GOV_SKILL="$ROOT/skills/scaffolding-governance-docs/SKILL.md"

# Extract the bash inside a numbered section (e.g. "## 13.") up to the next "## " heading.
_extract_section_bash() {
  local file="$1" section="$2"
  awk -v sec="$section" '
    $0 ~ "^"sec { insec=1 }
    insec && /^## / && $0 !~ "^"sec { insec=0 }
    insec && /^```bash/ { inbash=1; next }
    insec && inbash && /^```/ { inbash=0; next }
    insec && inbash { print }
  ' "$file"
}

# SS-2 W1 — every lib helper the dispatch body calls is sourced in that section.
test_memory_bank_dispatch_sources_its_helpers() {
  echo "test_memory_bank_dispatch_sources_its_helpers:"
  local body; body="$(_extract_section_bash "$MB_SKILL" "## 13")"
  local missing=0 h
  # helpers called by §13 that live OUTSIDE synthesis.sh/routing.sh
  for h in sf_memory_bank_derive sf_claude_md_generate sf_claude_settings_generate \
           sf_agents_md_generate _memory_bank_args _sf_mb_extract_preserve_zone \
           _sf_mb_reinject_preserve_zone sf_render; do
    if printf '%s' "$body" | grep -q "$h"; then
      # it's called — assert §13 sources a lib that defines it
      if ! grep -qE 'source .*/lib/(memory-bank|render)\.sh' "$MB_SKILL"; then
        echo "  ✗ §13 calls $h but never sources memory-bank.sh/render.sh"; missing=$((missing+1)); break
      fi
    fi
  done
  if [[ "$missing" == "0" ]]; then PASS=$((PASS+1)); echo "  ✓ §13 sources the libs its body calls"; else FAIL=$((FAIL+1)); fi
}

test_governance_dispatch_sources_its_helpers() {
  echo "test_governance_dispatch_sources_its_helpers:"
  local body; body="$(_extract_section_bash "$GOV_SKILL" "## 11")"
  if printf '%s' "$body" | grep -qE 'sf_docs_derive|_write_or_skip'; then
    if grep -qE 'source .*/lib/docs\.sh' "$GOV_SKILL"; then
      PASS=$((PASS+1)); echo "  ✓ §11 sources docs.sh"
    else
      FAIL=$((FAIL+1)); echo "  ✗ §11 calls sf_docs_derive but never sources docs.sh"
    fi
  else
    PASS=$((PASS+1)); echo "  ✓ §11 does not call docs.sh helpers"
  fi
}

# SS-2 W1 — the fast-path short-circuit must REALLY exit, not a comment-only STOP.
test_fast_path_has_real_control_flow() {
  echo "test_fast_path_has_real_control_flow:"
  local ok=1 f
  for f in "$MB_SKILL" "$GOV_SKILL"; do
    # the fast-path block must contain an explicit return/exit, not just "# STOP"
    if ! awk '/sf_synth_mode.*==.*"fast"/{f=1} f&&/^```/{f=0} f' "$f" | grep -qE '\b(return|exit)\b'; then
      echo "  ✗ $(basename "$(dirname "$f")") fast-path has no real return/exit"; ok=0
    fi
  done
  if [[ "$ok" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ both fast-paths exit explicitly"; else FAIL=$((FAIL+1)); fi
}

test_memory_bank_dispatch_sources_its_helpers
test_governance_dispatch_sources_its_helpers
test_fast_path_has_real_control_flow
report_results
```

- [ ] **Step 2: Run, confirm FAIL**

Run: `bash scaffold-onboard/run-tests.sh tests/test-synthesis-dispatch.sh`
Expected: FAIL — §13.1/§11.1 don't source memory-bank.sh/docs.sh; fast-paths have comment-only STOP.

- [ ] **Step 3: Fix memory-bank §13.1 setup + §13.2 fast-path**

In `scaffolding-memory-bank/SKILL.md` §13.1, change the setup source block from:
```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/synthesis.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/routing.sh"
```
to (add the two libs the dispatch/fallback/finalize body calls):
```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/synthesis.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/routing.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/memory-bank.sh"   # sf_memory_bank_derive, sf_claude_*, _memory_bank_args, _sf_mb_*
source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"        # sf_render (per-artifact fallback)
```

In §13.2, change the fast-path block from:
```bash
if [[ "$(sf_synth_mode)" == "fast" ]]; then
  sf_memory_bank_derive [--force]   # deterministic path; --force passed through if --regenerate was set
  sf_claude_md_generate
  # STOP — do not execute synthesis waves
fi
```
to (real control-flow — the orchestrator executes this as a guarded early return of the dispatch routine):
```bash
if [[ "$(sf_synth_mode)" == "fast" ]]; then
  sf_memory_bank_derive ${regenerate:+--force}   # deterministic path; --force when --regenerate set
  sf_claude_md_generate
  return 0   # STOP: do NOT fall through into the synthesis waves below
fi
```
Add one prose line under the block: *"The `return 0` is load-bearing — a bare `# STOP` comment does not stop execution; the fast-path must exit the dispatch routine before the waves."*

- [ ] **Step 4: Fix governance §11.1 setup + §11.2 fast-path**

In `scaffolding-governance-docs/SKILL.md` §11.1, change the setup source block from:
```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/synthesis.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/routing.sh"
```
to:
```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/synthesis.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/routing.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/docs.sh"   # sf_docs_derive + _write_or_skip (fast-path + per-artifact fallback)
```

In §11.2, change:
```bash
if [[ "$(sf_synth_mode)" == "fast" ]]; then
  sf_docs_derive [--full] --fast   # deterministic path; --full passed through if the user passed it
  # STOP — do not execute synthesis waves
fi
```
to:
```bash
if [[ "$(sf_synth_mode)" == "fast" ]]; then
  sf_docs_derive ${full:+--full} --fast   # deterministic path; --full passed through if the user passed it
  return 0   # STOP: do NOT fall through into the synthesis waves below
fi
```

- [ ] **Step 5: Run, confirm PASS + full suite**

Run: `bash scaffold-onboard/run-tests.sh tests/test-synthesis-dispatch.sh` → the 3 W1 tests green.
Run: `bash scaffold-onboard/run-tests.sh` → all green.

- [ ] **Step 6: Commit**
```bash
git add scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md \
        scaffold-onboard/skills/scaffolding-governance-docs/SKILL.md \
        scaffold-onboard/tests/test-synthesis-dispatch.sh
git commit -m "fix(scaffold-onboard): source dispatch libs + real fast-path return in synthesis SKILLs (SS-2 W1, #50)"
```

---

## Task 2 (W2): EXECUTIVE-SUMMARY synthesis — single authoritative producer + parser contract

**Files:**
- Create: `scaffold-onboard/templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md`
- Modify: `scaffold-onboard/lib/render.sh` (implement real `sf_render_executive_summary` + `sf_master_spec_section` extractor + `sf_exec_summary_staleness`)
- Modify: `scaffold-onboard/skills/onboarding-project/SKILL.md` (§8 — produce EXEC-SUMMARY for real)
- Modify: `scaffold-onboard/skills/onboarding-project/references/example-walkthrough.md` (line ~213 — remove phantom claim)
- Modify: `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md` §13.1 + `scaffolding-governance-docs/SKILL.md` §11.1 (consume-if-missing + staleness warning)
- Test: `scaffold-onboard/tests/test-synthesis-dispatch.sh`

**Design:** EXEC-SUMMARY is **spec-derived**, produced/refreshed by exactly one owner — `onboarding-project` at Phase-10 close (synthesis-agent by default; `sf_render_executive_summary` deterministic on `--fast`/fallback). `/scaffold-*` only consume it: produce-once if missing (legacy projects), never refresh, and warn if it's stale vs MASTER-SPEC. The deterministic renderer extracts MASTER-SPEC's pinned `## Executive Summary` section with an explicit absent/empty/duplicated contract.

- [ ] **Step 1: Write failing tests for the renderer + parser contract + staleness**

Add to `scaffold-onboard/tests/test-synthesis-dispatch.sh` (functions + invocations before `report_results`). These source the libs directly:

```bash
source "$ROOT/lib/_helpers.sh"
source "$ROOT/lib/render.sh"

_mk_master_spec_with_exec() {
  local dir="$1" body="$2"
  cat > "$dir/MASTER-SPEC.md" <<EOF
# test-proj — Master Spec

## Executive Summary
$body

## Phase 1: Foundation
stuff
EOF
}

test_render_exec_summary_from_section() {
  echo "test_render_exec_summary_from_section:"
  setup_tmp_repo
  _mk_master_spec_with_exec "$PWD" "test-proj builds widgets fast for solo devs."
  sf_render_executive_summary "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "test-proj" "CLI tool"
  assert_file_exists "$PWD/EXECUTIVE-SUMMARY.md"
  assert_file_contains "$PWD/EXECUTIVE-SUMMARY.md" "builds widgets fast for solo devs"
  assert_file_contains "$PWD/EXECUTIVE-SUMMARY.md" "cksum:"   # provenance trailer
}

test_render_exec_summary_errors_on_missing_section() {
  echo "test_render_exec_summary_errors_on_missing_section:"
  setup_tmp_repo
  printf '# test-proj\n\n## Phase 1\nstuff\n' > "$PWD/MASTER-SPEC.md"   # no Executive Summary
  set +e
  sf_render_executive_summary "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "test-proj" "CLI tool" 2>/dev/null
  local rc=$?
  set -e 2>/dev/null || true
  if [[ "$rc" != "0" ]]; then PASS=$((PASS+1)); echo "  ✓ errors (rc=$rc) on missing/empty Executive Summary"; else FAIL=$((FAIL+1)); echo "  ✗ silently produced a summary"; fi
}

test_exec_summary_staleness_detects_master_change() {
  echo "test_exec_summary_staleness_detects_master_change:"
  setup_tmp_repo
  _mk_master_spec_with_exec "$PWD" "original summary"
  sf_render_executive_summary "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" "test-proj" "CLI tool"
  # fresh: not stale
  sf_exec_summary_staleness "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" && local fresh=0 || local fresh=1
  # mutate MASTER-SPEC -> stale
  printf '\nmore content\n' >> "$PWD/MASTER-SPEC.md"
  sf_exec_summary_staleness "$PWD/MASTER-SPEC.md" "$PWD/EXECUTIVE-SUMMARY.md" && local stale=0 || local stale=1
  if [[ "$fresh" == "0" && "$stale" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ fresh=ok, post-edit=stale"; else FAIL=$((FAIL+1)); echo "  ✗ fresh=$fresh stale=$stale"; fi
}
```

Add the three names to the invocation list.

- [ ] **Step 2: Run, confirm FAIL** — `sf_render_executive_summary` / `sf_exec_summary_staleness` undefined.

- [ ] **Step 3: Implement the helpers in `lib/render.sh`**

Append to `scaffold-onboard/lib/render.sh`:

```bash
# Echo the body of MASTER-SPEC's "## Executive Summary" section (first match),
# stopping at the next "## " heading. Empty output if absent.
sf_master_spec_section() {
  local file="$1" heading="$2"
  awk -v h="## $heading" '
    $0==h { grab=1; next }
    grab && /^## / { exit }
    grab { print }
  ' "$file"
}

# Implement the (previously phantom) deterministic EXEC-SUMMARY renderer.
# Args: <master-spec-path> <out-path> <project_name> <project_class>
# Extracts MASTER-SPEC "## Executive Summary"; ERRORS (rc=1) if absent/empty —
# never emits a silent thin summary. Appends a cksum provenance trailer.
sf_render_executive_summary() {
  local master="$1" out="$2" project_name="$3" project_class="$4"
  [[ -f "$master" ]] || { sf_log_error "sf_render_executive_summary: MASTER-SPEC not found: $master"; return 1; }
  local body; body="$(sf_master_spec_section "$master" "Executive Summary")"
  # strip leading/trailing blank lines
  body="$(printf '%s\n' "$body" | sed -e '/./,$!d' | awk 'NF{n=NR} {a[NR]=$0} END{for(i=1;i<=n;i++)print a[i]}')"
  if [[ -z "${body// /}" ]]; then
    sf_log_error "sf_render_executive_summary: MASTER-SPEC has no non-empty '## Executive Summary' section. Add one (it is the pinned source for EXECUTIVE-SUMMARY.md), then re-run."
    return 1
  fi
  local root tmpl; root="$(sf_plugin_root)"; tmpl="$root/templates/master-spec/EXECUTIVE-SUMMARY.md.tmpl"
  local created; created="$(date -u +%Y-%m-%d)"
  sf_render "$tmpl" \
    "project_name=$project_name" \
    "executive_summary=$body" \
    "project_class=$project_class" \
    "created_date=$created" > "$out"
  # provenance trailer for staleness detection (cksum of the SOURCE master spec)
  printf '\n<!-- derived from MASTER-SPEC.md cksum:%s -->\n' "$(cksum < "$master" | awk '{print $1"-"$2}')" >> "$out"
}

# Return 0 if EXEC-SUMMARY is FRESH vs MASTER-SPEC, 1 if STALE/missing-trailer.
sf_exec_summary_staleness() {
  local master="$1" exec_summary="$2"
  [[ -f "$exec_summary" ]] || return 1
  local cur trailer
  cur="$(cksum < "$master" | awk '{print $1"-"$2}')"
  trailer="$(grep -oE 'cksum:[0-9]+-[0-9]+' "$exec_summary" | tail -1 | sed 's/cksum://')"
  [[ -n "$trailer" && "$trailer" == "$cur" ]]
}
```

(macOS portability: `cksum`, BSD `awk`/`sed` only. The blank-line trim is awk-based to avoid GNU `sed -z`.)

- [ ] **Step 4: Run, confirm PASS** — the three W2 tests green.

- [ ] **Step 5: Create the EXEC-SUMMARY synthesis brief**

Create `scaffold-onboard/templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md`:

```markdown
---
doc: EXECUTIVE-SUMMARY
routes_to: executive_summary
wave: 0
required_sections:
  - "Executive Summary"
mints: []
consumes: []
model: sonnet
---
## Synthesis guidance

This is the project's standalone executive summary — the one-page orientation a
stakeholder reads before MASTER-SPEC. SOURCE IS MASTER-SPEC ONLY (EXECUTIVE-SUMMARY.md
does not exist yet when you run; do not attempt to read it).

Synthesize a crisp summary (4–8 sentences or tight bullets) from MASTER-SPEC's vision
and problem (`phase_1.1.1`, `phase_1.1.2`), primary users (`phase_1.2.1`), MVP
(`phase_1.3.2`), and success criteria (Phase 2.3). Lead with what the product is and
for whom; name the core problem; state the MVP boundary and the top success signal.
Use the project's own domain vocabulary — no generic filler, no fill-in markers.

Emit exactly the `## Executive Summary` heading followed by the summary content.
```

> Note: this brief's `consumes: []` and the SOURCE-IS-MASTER-SPEC-ONLY guidance handle the chicken-and-egg (EXEC-SUMMARY synthesizing itself). When dispatched, pass an **empty** `exec_summary` arg to `sf_synth_brief_assemble` so the agent isn't told to read a file that doesn't exist.

- [ ] **Step 6: Make onboarding §8 the single authoritative producer**

In `scaffolding/onboarding-project/SKILL.md` §8, the close action currently assumes EXECUTIVE-SUMMARY.md "is rendered" (via the phantom). Replace the implicit render with an explicit producer block before the close summary:

```markdown
**Produce EXECUTIVE-SUMMARY.md (single authoritative producer).** EXEC-SUMMARY is
spec-derived from MASTER-SPEC and authored HERE — `/scaffold-project` and
`/scaffold-docs` only consume it. Default = synthesis; `--fast` = deterministic.

- **Synthesis (default):** dispatch the EXEC-SUMMARY brief from MASTER-SPEC only:
  ```bash
  brief="${CLAUDE_PLUGIN_ROOT}/templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md"
  out="$(sf_resolve_output_path executive_summary EXECUTIVE-SUMMARY.md)"
  master="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
  prompt="$(sf_synth_brief_assemble "$brief" "$(sf_synth_ledger_empty)" "$out" "$master" "")"
  Task(subagent_type="scaffold-onboard:synthesis-agent", description="Synthesize EXECUTIVE-SUMMARY", model="claude-sonnet-4-5", prompt="$prompt")
  ```
  After `mode:complete`, append the provenance trailer:
  ```bash
  printf '\n<!-- derived from MASTER-SPEC.md cksum:%s -->\n' "$(cksum < "$master" | awk '{print $1"-"$2}')" >> "$out"
  ```
- **Deterministic (`--fast` / synthesis fallback):**
  ```bash
  source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"
  sf_render_executive_summary "$master" "$out" "$(sf_project_name)" "$(sf_state_read_answer 1.3.1)"
  ```
  `sf_render_executive_summary` errors loudly if MASTER-SPEC has no `## Executive Summary`
  section (the pinned parser contract) — never a silent thin summary.
```

- [ ] **Step 7: Remove the phantom reference**

In `scaffold-onboard/skills/onboarding-project/references/example-walkthrough.md` (line ~213) replace:
> `EXECUTIVE-SUMMARY.md is rendered via `sf_render_executive_summary`. Paths are resolved through `sf_resolve_output_path`:`

with:
> `EXECUTIVE-SUMMARY.md is produced at onboarding close — synthesized from MASTER-SPEC by default (the `EXECUTIVE-SUMMARY.brief.md` synthesis-agent), or deterministically via `sf_render_executive_summary` under `--fast`. Paths are resolved through `sf_resolve_output_path`:`

Grep-verify no phantom remains: `grep -rn 'sf_render_executive_summary' scaffold-onboard/skills/` should show only the real call sites (no "does not exist" context). Add a test assertion:

```bash
test_no_phantom_exec_summary_render() {
  echo "test_no_phantom_exec_summary_render:"
  # the function must be DEFINED in lib (not just referenced)
  if grep -q 'sf_render_executive_summary()' "$ROOT/lib/render.sh"; then
    PASS=$((PASS+1)); echo "  ✓ sf_render_executive_summary is implemented in lib/render.sh"
  else
    FAIL=$((FAIL+1)); echo "  ✗ sf_render_executive_summary still phantom"
  fi
}
```
Add `test_no_phantom_exec_summary_render` to the invocation list.

- [ ] **Step 8: Add consume-if-missing + staleness warning to both dispatch §setup blocks**

In `scaffolding-memory-bank/SKILL.md` §13.1 and `scaffolding-governance-docs/SKILL.md` §11.1, after the `exec_summary="$(...)"` resolution line, add:

```bash
# EXEC-SUMMARY is produced by onboarding (single authoritative producer). Here we
# only CONSUME it: produce-once if a legacy project lacks it, and warn (never
# silently refresh) if it is stale vs MASTER-SPEC.
if [[ ! -f "$exec_summary" ]]; then
  source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"
  sf_render_executive_summary "$master" "$exec_summary" "$(sf_project_name)" "$(sf_state_read_answer 1.3.1)" \
    || sf_log_warn "could not produce EXECUTIVE-SUMMARY.md — run /onboard to author it"
elif ! sf_exec_summary_staleness "$master" "$exec_summary"; then
  sf_log_warn "EXECUTIVE-SUMMARY.md is older than MASTER-SPEC.md — re-run onboarding synthesis to refresh it (this command consumes but does not refresh the summary)."
fi
```

- [ ] **Step 9: Run full suite + commit**

Run: `bash scaffold-onboard/run-tests.sh` → all green (incl. `test-synthesis.sh` — confirm `EXECUTIVE-SUMMARY.brief.md` passes the existing `test_all_shipped_briefs_validate` sweep; if that test enumerates briefs, the new brief must satisfy `sf_synth_brief_validate`).
```bash
git add scaffold-onboard/templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md \
        scaffold-onboard/lib/render.sh \
        scaffold-onboard/skills/onboarding-project/SKILL.md \
        scaffold-onboard/skills/onboarding-project/references/example-walkthrough.md \
        scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md \
        scaffold-onboard/skills/scaffolding-governance-docs/SKILL.md \
        scaffold-onboard/tests/test-synthesis-dispatch.sh
git commit -m "feat(scaffold-onboard): synthesize EXECUTIVE-SUMMARY (single producer) + real sf_render_executive_summary + staleness (SS-2 W2, #49)"
```

---

## Task 3 (W3): `derivation-reviewer` agent + advisory review with disposition lifecycle

**Files:**
- Create: `scaffold-onboard/agents/derivation-reviewer.md`
- Modify: `scaffolding-memory-bank/SKILL.md` (new §14) + `scaffolding-governance-docs/SKILL.md` (new §12) — dispatch the review post-waves
- Test: `scaffold-onboard/tests/test-synthesis-dispatch.sh`

- [ ] **Step 1: Write the failing agent-exists test**

Add to the test file:
```bash
test_derivation_reviewer_agent_registered() {
  echo "test_derivation_reviewer_agent_registered:"
  local a="$ROOT/agents/derivation-reviewer.md"
  if [[ -f "$a" ]] && grep -q 'name: derivation-reviewer' "$a" && grep -qE 'tools:.*Read' "$a" && ! grep -qE 'tools:.*Write' "$a"; then
    PASS=$((PASS+1)); echo "  ✓ derivation-reviewer registered, read-only (no Write/Task)"
  else
    FAIL=$((FAIL+1)); echo "  ✗ derivation-reviewer missing or not read-only"
  fi
}
```
Add to invocation list.

- [ ] **Step 2: Run, confirm FAIL** (agent doesn't exist).

- [ ] **Step 3: Create the agent**

Create `scaffold-onboard/agents/derivation-reviewer.md`:

```markdown
---
name: derivation-reviewer
description: Advisory post-derivation reviewer. Reads a freshly synthesized scaffold-onboard bundle (memory-bank or governance docs) plus MASTER-SPEC.md + EXECUTIVE-SUMMARY.md and reports content-quality findings — faithfulness to the spec, hallucinations, unmet FR/NFR, thin/weak sections. NON-BLOCKING and read-only: it writes one report and never edits the bundle or dispatches further agents.
tools: Read, Grep, Glob, Write
model: inherit
---

You review one freshly derived bundle for content quality. The invocation prompt
names: the bundle directory, the list of artifact paths, MASTER-SPEC.md, and
EXECUTIVE-SUMMARY.md, and the MASTER-SPEC content-hash you are reviewing against.

## What you check (advisory only)
- **Faithfulness:** does each artifact reflect MASTER-SPEC / EXEC-SUMMARY, or drift / invent?
- **Hallucinations:** claims, stacks, or requirements not grounded in the sources.
- **Coverage:** FR/NFR or use cases in the spec that no artifact addresses.
- **Thin sections:** required sections present but generic / low-signal.

## You do NOT
- Edit any artifact (you have Write ONLY to author the single report below).
- Block, gate, or re-run derivation. Your output is advice; the user decides.
- Dispatch sub-agents (no Task).

## Output: write `<bundle-dir>/derivation-review.md`
For each finding, one row tagged by the **target filename** and a disposition:
```
## Derivation review — <bundle> (against MASTER-SPEC cksum:<hash>)

| file | severity | finding | disposition |
|---|---|---|---|
| 03-code-patterns.md | medium | invents a "Redis cache" not in MASTER-SPEC | regenerate 03-code-patterns.md |
| PRD.md | low | "Goals" section is generic | edit |
| index.md | ok | faithful | accept |
```
Disposition vocabulary: `accept` / `regenerate <file>` / `edit`. For every
`regenerate <file>`, the orchestrator surfaces the supported boolean command
`/scaffold-project --regenerate` (or the governance equivalent) plus the artifact
name to re-dispatch internally through the per-artifact synthesis loop — so the
finding is actionable without adding a public per-file flag. End your message
with: `{"mode":"review-complete","report":"<abs path>","findings":<N>}`.
```

- [ ] **Step 4: Document the dispatch in both SKILLs**

In `scaffolding-memory-bank/SKILL.md`, add a new section after §13:

```markdown
## 14. Post-derivation review (#42 — advisory, SS-2)

After the synthesis waves complete (synthesize mode only — skip under `--fast`),
dispatch ONE read-only review over the bundle. Non-blocking: surface the report,
do not gate.

​```bash
master_hash="$(cksum < "$master" | awk '{print $1"-"$2}')"
bundle="$(sf_resolve_output_path memory_bank .claude/memory-bank)"
review_prompt="Review the freshly synthesized memory-bank bundle at ${bundle} (00-04,07,08,index.md + CLAUDE.md) against MASTER-SPEC ${master} (cksum:${master_hash}) and EXECUTIVE-SUMMARY ${exec_summary}. Write ${bundle}/derivation-review.md per your contract."
Task(subagent_type="scaffold-onboard:derivation-reviewer", description="Review memory-bank derivation", model="claude-sonnet-4-5", prompt="$review_prompt")
​```

On `review-complete`: print the report path + a one-line summary, and for each
`regenerate <file>` finding surface `/scaffold-project --regenerate` plus the
single artifact name to re-dispatch internally through the §13.3 per-artifact
loop. The user decides; nothing is auto-applied.
```

In `scaffolding-governance-docs/SKILL.md`, add the analogous section after §11 (§12), pointing `bundle` at `docs/` and listing the governance artifacts, with the supported boolean apply command `/scaffold-docs --regenerate` plus internal single-artifact re-dispatch.

> **Targeted regenerate (apply path):** keep the user-facing CLI aligned with the supported boolean `--regenerate`. Per-file targeting is an orchestration action: re-dispatch just that artifact's synthesis brief (the dispatch loop is per-artifact already). Document this; no new lib or slash-command flag is required for SS-2.

- [ ] **Step 5: Run + commit**

Run: `bash scaffold-onboard/run-tests.sh tests/test-synthesis-dispatch.sh` → green. Full suite green.
```bash
git add scaffold-onboard/agents/derivation-reviewer.md \
        scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md \
        scaffold-onboard/skills/scaffolding-governance-docs/SKILL.md \
        scaffold-onboard/tests/test-synthesis-dispatch.sh
git commit -m "feat(scaffold-onboard): advisory derivation-reviewer agent + recorded disposition lifecycle (SS-2 W3, #42)"
```

---

## Task 4 (W4): Behavioral dispatch harness — the real OQ-1 closer

**Files:**
- Modify: `scaffold-onboard/tests/test-synthesis-dispatch.sh`

**Design:** Extract the actual ```bash blocks from §13 of the memory-bank SKILL, provide a `Task()` shell shim (writes a stub artifact + emits a fake `mode:complete` return), seed fixture vars the orchestrator would bind (`$master`, `$exec_summary`, `$regenerate`, `$out`, `$brief`, `$ledger`), and run the **executable** portions under `set -euo pipefail`. If any helper is unsourced or any var unbound, the run aborts → the OQ-1 class fails the test for real. The interleaved `Task(...)` notation is neutralized by the shim. (Honest boundary per spec §2.5: this proves the *shell* is executable; it cannot prove the LLM chooses to dispatch.)

- [ ] **Step 1: Write the behavioral harness test (failing until W1 is in)**

Add to `scaffold-onboard/tests/test-synthesis-dispatch.sh`:

```bash
# SS-2 W4 — behavioral: the executable shell of §13 (setup + fast-path + per-artifact
# fallback + finalize) runs under `set -euo pipefail` with a faked Task. A regression of
# the unsourced-helper / unbound-var class aborts this test.
test_memory_bank_dispatch_executes_under_set_u() {
  echo "test_memory_bank_dispatch_executes_under_set_u:"
  setup_tmp_repo
  seed_master_spec   # from test-memory-bank.sh helpers? if unavailable, inline a minimal MASTER-SPEC + state
  local driver="$TMP_DIR/driver.sh"
  {
    echo 'set -euo pipefail'
    echo "export CLAUDE_PLUGIN_ROOT='$ROOT'"
    echo 'sf_log_info(){ :; }; sf_log_warn(){ :; }; sf_log_error(){ :; }'   # quiet
    # fixture vars the orchestrator binds:
    echo 'regenerate=0; full=0'
    # Task shim: write a minimal valid artifact to $out (so fallback/validation has a file)
    echo 'Task(){ :; }'   # the notation Task(subagent_type=...) parses as a function call w/ no-op
    # --- BEHAVIORAL CORE: source the libs §13.1 declares, then run the fast-path + finalize shell ---
    echo 'source "${CLAUDE_PLUGIN_ROOT}/lib/synthesis.sh"'
    echo 'source "${CLAUDE_PLUGIN_ROOT}/lib/routing.sh"'
    echo 'source "${CLAUDE_PLUGIN_ROOT}/lib/memory-bank.sh"'
    echo 'source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"'
    echo 'export SF_SYNTH_FAST=1'   # exercise the fast-path branch end-to-end (deterministic, no real agents)
    echo 'master="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"'
    echo 'exec_summary="$(sf_resolve_output_path executive_summary EXECUTIVE-SUMMARY.md)"'
    echo 'if [[ "$(sf_synth_mode)" == "fast" ]]; then sf_memory_bank_derive ${regenerate:+--force}; sf_claude_md_generate; fi'
    # finalize helpers the synthesize path also calls (prove they are callable):
    echo 'sf_claude_settings_generate'
    echo 'sf_agents_md_generate'
    echo 'echo DISPATCH_SHELL_OK'
  } > "$driver"
  local outp; outp="$(cd "$PWD" && bash "$driver" 2>"$TMP_DIR/err.txt")"
  if printf '%s' "$outp" | grep -q DISPATCH_SHELL_OK && [[ -f "$PWD/.claude/memory-bank/00-project-brief.md" ]]; then
    PASS=$((PASS+1)); echo "  ✓ dispatch shell executes under set -euo pipefail (no unsourced-helper abort)"
  else
    FAIL=$((FAIL+1)); echo "  ✗ dispatch shell aborted:"; sed 's/^/      /' "$TMP_DIR/err.txt" | head -8
  fi
}
```

> Implementation note for the engineer: `seed_master_spec` lives in `tests/test-memory-bank.sh`; either `source` that file's helper or inline a minimal MASTER-SPEC + `onboarding-state.json` (call `sf_state_init` + a few `sf_state_write_answer` like test-memory-bank does). The harness exercises the **fast-path branch** because it is the deterministic executable core shared with the synthesize-path finalize; this is what catches the unsourced-helper abort. Pair it with the source-guard (Task 1) which binds the assertion to the SKILL text so the synthesize-only blocks can't silently drift.

Add `test_memory_bank_dispatch_executes_under_set_u` to the invocation list.

- [ ] **Step 2: Run — confirm it PASSES now that W1 sourced the libs** (and would FAIL if you revert W1's `source memory-bank.sh`/`render.sh` lines — verify by temporarily removing them, re-running, restoring).

- [ ] **Step 3: Add the per-artifact fallback-domain contract test**

Add a test that forces one artifact's validation to fail and asserts only that artifact falls back while siblings are preserved (uses the deterministic path as the stand-in for a fallback render):

```bash
test_fallback_is_per_artifact() {
  echo "test_fallback_is_per_artifact:"
  setup_tmp_repo; seed_master_spec
  source "$ROOT/lib/memory-bank.sh"
  sf_memory_bank_derive    # produce a full deterministic bundle (stands in for synthesized siblings)
  # simulate: 02 is "bad" -> re-render only 02 deterministically; assert 00/04 untouched
  local before00; before00="$(cksum < "$PWD/.claude/memory-bank/00-project-brief.md")"
  sf_render "$ROOT/templates/memory-bank/02-system-patterns.md.tmpl" ts=x > "$PWD/.claude/memory-bank/02-system-patterns.md" 2>/dev/null || true
  local after00; after00="$(cksum < "$PWD/.claude/memory-bank/00-project-brief.md")"
  if [[ "$before00" == "$after00" ]]; then PASS=$((PASS+1)); echo "  ✓ per-artifact fallback leaves siblings untouched"; else FAIL=$((FAIL+1)); fi
}
```
Add to invocation list. (This pins the documented per-artifact failure domain from spec §2.6.)

- [ ] **Step 4: Run full suite + commit**

Run: `bash scaffold-onboard/run-tests.sh` → all green.
```bash
git add scaffold-onboard/tests/test-synthesis-dispatch.sh
git commit -m "test(scaffold-onboard): behavioral dispatch harness + per-artifact fallback contract (SS-2 W4, #50)"
```

---

## Task 5 (W5): End-to-end smoke (supplementary evidence)

**Files:** none committed (verification + build-report note).

- [ ] **Step 1: Run a real synthesize-mode dispatch in-session**

This is an **agent-driven** verification (the controller, not a bash test): on a fixture project with a real MASTER-SPEC (use `scaffold-onboard/examples/sample-project/MASTER-SPEC.md` or seed one), follow `scaffolding-memory-bank` §13 in synthesize mode — actually dispatch the `synthesis-agent` Tasks — and confirm: dispatch fires, the 8 derived files + CLAUDE.md are authored, `sf_synth_assert_*` pass, the §14 `derivation-reviewer` runs and writes `derivation-review.md`, and `sf_memory_bank_derive --fast` + settings + AGENTS.md complete without abort.

- [ ] **Step 2: Record outcomes**

Note the result in the build/PR description (dispatch fired, bundle written, review ran). The W4 harness is the repeatable CI signal; this smoke is one-time supplementary evidence (spec §2.7). If the smoke surfaces a real dispatch defect, fix it (new test first) before release.

---

## Task 6 (W6): Release

**Files:** `scaffold-onboard/.claude-plugin/plugin.json` + `.codex-plugin/plugin.json`, `CHANGELOG.md`, root `README.md`.

- [ ] **Step 1: Bump both manifests 0.4.0 → 0.5.0** (Claude + Codex parity).
- [ ] **Step 2: CHANGELOG `[0.5.0]`** — synthesis dispatch made executable (#50), EXECUTIVE-SUMMARY synthesized (#49), advisory derivation-reviewer (#42), behavioral dispatch harness.
- [ ] **Step 3: README** — scaffold-onboard row → v0.5.0; note synthesis is now verified-executable + EXEC-SUMMARY synthesized.
- [ ] **Step 4: Gates** — `bash tests/test-codex-dual-publish.sh` (148+) + full suite green.
- [ ] **Step 5: PR → bot-review (Codex + CodeRabbit) → squash-merge → tag `scaffold-onboard-v0.5.0`** → close #50, #49, #42 → mark SS-2 SHIPPED in the program ledger.

---

## Self-Review

**1. Spec coverage:** W1 dispatch executability (§2.2) → Task 1; W2 EXEC-SUMMARY single producer + parser contract + staleness (§2.3, SP-1) → Task 2; W3 review lifecycle (§2.4, SP-2) → Task 3; W4 behavioral harness + per-artifact fallback domain (§2.5/§2.6, SP-4) → Task 4; W5 supplementary smoke (§2.7) → Task 5; W6 release → Task 6. Source-guard (secondary) → Task 1. Cost posture / scaffold-dev boundary (§6) → doc-only, no task needed. ✓

**2. Placeholder scan:** Version bumps in Task 6 are concrete (0.4.0→0.5.0). The W4 `seed_master_spec` reuse is flagged with a concrete inline fallback. No TODO/TBD in plan logic.

**3. Type/name consistency:** Helper names (`sf_render_executive_summary`, `sf_master_spec_section`, `sf_exec_summary_staleness`), the `## Executive Summary` heading, the `cksum:<sum>` trailer, logical names (`executive_summary`, `master_spec`, `memory_bank`), agent name (`derivation-reviewer`), report path (`derivation-review.md`), and the `accept`/`regenerate <file>`/`edit` disposition vocab are identical across Tasks 2-5. ✓

**4. Honest-boundary check:** The behavioral harness exercises the deterministic/fast-path executable core (which shares the finalize helpers with the synthesize path) + the source-guard binds assertions to the SKILL text — together they catch the OQ-1 unsourced-helper class. They do NOT prove the LLM dispatches (irreducibly prose); W5 smoke covers that once. This matches spec §2.5's stated limit.
