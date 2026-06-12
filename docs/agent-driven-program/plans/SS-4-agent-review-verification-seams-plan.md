# SS-4 — Agent-Review of Verification Seams Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the agent the single authority over every *semantic* judgment in scaffold-dev's four verification seams (harvest, lean-index linter, spec-citations, RED-tests gate); delete the competing semantic bash; keep only mechanical-execution legs. Ship `scaffold-dev` v0.4.0.

**Architecture:** One rule applied four times (spec §2): name each seam's mechanical leg (kept, deterministic) and agent-authority leg (sole judge). Delete bash that parses/judges; keep bash that runs real commands / writes with idempotency. All four seams run **inline** in the conducting agent's context (not via dispatch) — so there is no "agent unavailable" state and no fallback to preserve. Mechanical legs fail loud with remediation, never silently skip.

**Tech stack:** Bash (`sd_` libs, `set -u`), Markdown skill/template bodies, bash test harness, jq, eval Markdown scenarios. Dual-published (Claude `.claude-plugin/` + Codex `.codex-plugin/`).

**Design doc:** `docs/agent-driven-program/specs/SS-4-agent-review-verification-seams.md`
**Branch:** `feat/ss4-agent-review-seams` (create at execution start off `main`).

**Key facts confirmed during planning:**
- `lib/harvest.sh`: `sd_harvest_reports`, `sd_harvest_handoffs`, `_sd_harvest_extract_section` are semantic prose→JSON parsers and are **already orphaned** (no live `closing-vertical-slice` §9 caller). `sd_harvest_apply` + `_sd_harvest_seed_live_file` are mechanical I/O (write + idempotency + derived-reroute + provenance) — **kept**.
- `closing-vertical-slice` §9 step 7 currently has the **agent hand-author** the provenance trailer (which evals S1/S4 check char-for-char). SS-4 routes the write through `sd_harvest_apply` so the trailer is mechanical; the agent's job ends at producing the categorized JSON + decisions.
- `test-harvest.sh`: `test_reports_*` + `test_handoffs_*` test the deleted parsers (remove); `test_apply_*` test the kept writer (keep + extend).
- `executing-work-item` §3 is pre-flight, §4 is the per-AC TDD loop. The RED-gate is a new pre-flight sub-step **§3.6** running the `auto:` AC commands and asserting all currently fail — no §4 restructure.
- `planning-vertical-slice` §6 authors specs; §6.3 is gate-2 grill-me, §7 is architect-critic. The opt-in citation-check offer slots in as new **§6.4** (post-spec, before architect-critic).
- `scaffold-dev/templates/implementation-report.md.tmpl` §8 = "Suggestions for memory bank" (agent-read-note site).
- Version `0.3.0` in **both** `scaffold-dev/.claude-plugin/plugin.json` and `scaffold-dev/.codex-plugin/plugin.json` → bump both to `0.4.0`. Repo-root `tests/` parity guard runs after.
- Logging: `sd_log_info|warn|error` (`lib/_helpers.sh`); all write to stderr; `sd_log_error` **only logs**, does not exit — guard control flow explicitly.

**Verification commands:**
- Single file: `cd scaffold-dev && bash tests/<file>`
- Full suite: `cd scaffold-dev && bash run-tests.sh` (slow — run backgrounded, generous timeout)
- Dual-publish parity: `bash tests/test-codex-dual-publish.sh` (repo root)
- Residue sweep (after #52): `grep -rn 'sd_harvest_reports\|sd_harvest_handoffs\|_sd_harvest_extract_section' scaffold-dev | grep -v CHANGELOG`

---

## Phase A — Seam #52 (harvest single-authority) + #48-F (lean-index, harvest write-time)

### Task 1: Delete the orphaned semantic AWK parsers from `lib/harvest.sh`

**Files:**
- Modify: `scaffold-dev/lib/harvest.sh`
- Test: `scaffold-dev/tests/test-harvest.sh`

- [ ] **Step 1: Remove the parser tests first (TDD-red-removal).** In `tests/test-harvest.sh`, delete the test functions `test_reports_sweep_basic`, `test_reports_source_tag`, `test_reports_work_item`, `test_reports_target_file`, `test_reports_multi_workitem`, `test_reports_empty`, `test_handoffs_sweep`, `test_handoffs_source_tag`, `test_handoffs_filter`, and their registrations in the runner block. Keep all `test_apply_*` functions and any fixture helpers they share.

- [ ] **Step 2: Run the suite to confirm only apply-tests remain.**

Run: `cd scaffold-dev && bash tests/test-harvest.sh`
Expected: PASS — only `test_apply_*` cases execute, 0 failures, no reference errors.

- [ ] **Step 3: Delete the three semantic functions** from `lib/harvest.sh`: `_sd_harvest_extract_section` (lines ~85–103), `sd_harvest_reports` (lines ~105–174), `sd_harvest_handoffs` (lines ~176–212). Leave `sd_harvest_apply`, `_sd_harvest_seed_live_file`, `_sd_harvest_is_derived`, `_sd_harvest_onboard_template`, and the `_SD_HARVEST_DERIVED_FILES` data intact.

- [ ] **Step 4: Confirm no live caller references the deleted functions.**

Run: `grep -rn 'sd_harvest_reports\|sd_harvest_handoffs\|_sd_harvest_extract_section' scaffold-dev | grep -v CHANGELOG`
Expected: no matches (CHANGELOG history is allowed to mention them).

- [ ] **Step 5: Run the full harvest test + e2e to confirm green.**

Run: `cd scaffold-dev && bash tests/test-harvest.sh && bash tests/test-e2e.sh`
Expected: PASS (test-e2e harvest assertions are re-pointed in Task 5; if it fails on a deleted-fn reference, note it and fix in Task 5).

- [ ] **Step 6: Commit.**

```bash
git add scaffold-dev/lib/harvest.sh scaffold-dev/tests/test-harvest.sh
git commit -m "refactor(scaffold-dev): delete orphaned semantic harvest parsers (#52)"
```

### Task 2: Add the mechanical lean-index line-count helper (#48-F mechanical leg)

**Files:**
- Modify: `scaffold-dev/lib/harvest.sh`
- Test: `scaffold-dev/tests/test-harvest.sh`

- [ ] **Step 1: Write the failing tests.** Append to `tests/test-harvest.sh` and register in the runner:

```bash
test_lint_length_under_threshold() {
  # 3-line entry, default threshold 12 → lean (return 0)
  local text=$'line one\nline two\nline three'
  sd_harvest_lint_length "$text" >/dev/null
  assert_eq "$?" "0" "3-line entry is lean"
}

test_lint_length_over_threshold() {
  # 15-line entry, default threshold 12 → flagged (return 1), count echoed
  local text; text="$(printf 'l%.0s\n' $(seq 1 15))"
  local count rc
  count="$(sd_harvest_lint_length "$text")"; rc="$?"
  assert_eq "$rc" "1" "15-line entry is flagged"
  assert_eq "$count" "15" "echoes the line count"
}

test_lint_length_custom_threshold() {
  local text=$'a\nb\nc\nd\ne'   # 5 lines, threshold 4 → flagged
  sd_harvest_lint_length "$text" 4 >/dev/null
  assert_eq "$?" "1" "5-line entry flagged at threshold 4"
}
```

- [ ] **Step 2: Run to verify they fail.**

Run: `cd scaffold-dev && bash tests/test-harvest.sh`
Expected: FAIL — `sd_harvest_lint_length: command not found` / function undefined.

- [ ] **Step 3: Implement the helper** in `lib/harvest.sh` (after the kept helpers):

```bash
# sd_harvest_lint_length <text> [threshold]
# Mechanical lean-index leg (#48-F): echo the entry's line count; return 1 if it
# exceeds <threshold> (default 12), else 0. Pure count — the semantic "does this
# restate tracked content" judgment is the agent's (closing-vertical-slice §9.4).
sd_harvest_lint_length() {
  local text="$1" threshold="${2:-12}" count
  count="$(printf '%s\n' "$text" | grep -c '' )"
  echo "$count"
  (( count > threshold )) && return 1
  return 0
}
```

- [ ] **Step 4: Run to verify pass.**

Run: `cd scaffold-dev && bash tests/test-harvest.sh`
Expected: PASS — all three new cases + the kept `test_apply_*` green.

- [ ] **Step 5: Commit.**

```bash
git add scaffold-dev/lib/harvest.sh scaffold-dev/tests/test-harvest.sh
git commit -m "feat(scaffold-dev): add sd_harvest_lint_length lean-index helper (#48 Part F)"
```

### Task 3: Rewire `closing-vertical-slice` §9 — agent sole reader, `sd_harvest_apply` sole writer, fold in #48-F

**Files:**
- Modify: `scaffold-dev/skills/closing-vertical-slice/SKILL.md` (§9.3–§9.7, plus the §12-style "who does what" note at the bottom)

- [ ] **Step 1: §9.3 (Extract promote candidates)** — add a sentence making the agent the explicit sole reader and naming the now-dissolved collision:

> The implementer's `report.md` "Suggestions for memory bank" section is **free-form prose**, **agent-read, not machine-parsed** — read it with judgment; there is no bullet grammar to satisfy. (Per SS-4 / #52: the former `sd_harvest_reports`/`sd_harvest_handoffs` AWK parsers are deleted; you are the single authority over extraction.)

- [ ] **Step 2: §9.4 (Categorize)** — append the #48-F semantic lean-index check as part of the agent's per-candidate judgment, before it proposes a target:

> **Lean-index check (#48-F, write-time prevention).** Before proposing a target, judge whether the candidate **restates content already tracked** in a doc/ADR/issue (MASTER-SPEC §-ref, an existing ADR id, an open issue). If it does, do NOT harvest the prose — surface a pointer instead (e.g. "see ADR-0007" / "tracked in #N") and route the deferral via `Skill(scaffold-dev:deferring-work-item)` if it is genuinely new debt. Also run the **mechanical length leg** through the dispatcher: `sd harvest_lint_length "<candidate text>"` — if it returns non-zero (exceeds ~12 lines), the entry is too long for a lean index; ask the user to tighten it to a pointer + one-line gist before accepting. These checks are advisory nudges surfaced at step 5, not hard blocks.

- [ ] **Step 3: §9.7 (Apply with provenance trailer)** — replace the "agent appends directly" mechanics with a single mechanical writer call backed by `sd_harvest_apply` so the trailer is mechanical:

> Build a JSON array of the accepted/edited candidates — each object `{source, target_file, suggestion}` (report-origin) or `{source, target_file, handoff_file, item}` (handoff-origin) — and apply them in one call:
> ```bash
> sd_harvest_apply "$accepted_json" "VS-N.M.K"
> ```
> `sd_harvest_apply` is the **single mechanical write authority**: it writes each item to its target memory-bank file with the exact provenance trailer, enforces idempotency (skips text already present), and reroutes any spec-derived target to `09-known-issues.md` with a warning. Do **not** hand-author the trailer or append directly — the trailer format is load-bearing (eval S4) and belongs to the helper. `reject` items are simply omitted from the array.

- [ ] **Step 4:** Update the bottom "**You** / **Bash helpers**" responsibilities note so `lib/harvest.sh` is listed among the bash helpers (it was omitted), described as "harvest write + idempotency + derived-reroute (`sd_harvest_apply`) and the lean-index length leg (`sd_harvest_lint_length`)".

- [ ] **Step 5:** Sanity-check the skill reads coherently end-to-end (§9.1→§9.8 still an 8-step flow; the agent reads → judges/categorizes/lean-checks → surfaces → consumes decisions → builds JSON → one `sd_harvest_apply`-backed write → records outcomes).

- [ ] **Step 6: Commit.**

```bash
git add scaffold-dev/skills/closing-vertical-slice/SKILL.md
git commit -m "refactor(scaffold-dev): agent-sole-reader harvest + sd_harvest_apply sole writer + lean-index check (#52, #48 Part F)"
```

### Task 4: Add the agent-read note to the report template

**Files:**
- Modify: `scaffold-dev/templates/implementation-report.md.tmpl` (§8 heading area)

- [ ] **Step 1:** Under the `## 8. Suggestions for memory bank` heading, add one HTML-comment guidance line (invisible in rendered prose, visible to the authoring agent):

```markdown
## 8. Suggestions for memory bank
<!-- Free-form prose. Agent-read at slice-close harvest (closing-vertical-slice §9), NOT machine-parsed — no bullet grammar required. Note caveats/patterns worth promoting; the harvest agent categorizes and applies. -->
```

- [ ] **Step 2:** Confirm no test asserts an exact byte-count / line-count of this template that the added comment would break.

Run: `grep -rn 'implementation-report' scaffold-dev/tests`
Expected: any matching test still passes (run it); if a test pins template content, update its expectation to include the comment.

- [ ] **Step 3: Commit.**

```bash
git add scaffold-dev/templates/implementation-report.md.tmpl
git commit -m "docs(scaffold-dev): mark report Suggestions section agent-read not machine-parsed (#52)"
```

### Task 5: Re-point `test-e2e.sh` harvest assertions + update evals

**Files:**
- Modify: `scaffold-dev/tests/test-e2e.sh`
- Modify: `scaffold-dev/evals/closing-vertical-slice.md` (S1/S4 harvest scenarios — if present under that path)

- [ ] **Step 1:** In `test-e2e.sh`, find any assertion that calls or depends on `sd_harvest_reports`/`sd_harvest_handoffs`. Re-point each to the kept contract: seed a `report.md` with a free-form Suggestions section + an accepted-items JSON, call the harvest writer, and assert the target memory-bank file received the item + provenance trailer (the agent-reading step is exercised by evals, not the bash e2e).

- [ ] **Step 2: Run e2e to confirm green.**

Run: `cd scaffold-dev && bash tests/test-e2e.sh`
Expected: PASS.

- [ ] **Step 3:** In the `closing-vertical-slice` eval scenarios (S1/S4), update the harvest expectations: the agent reads free-form prose (no grammar), the **write** is an `sd_harvest_apply`-backed invocation (assert the call + resulting file content + trailer, not a hand-authored agent `Write` of the trailer). Add one assertion that a candidate exceeding the lean-index length is surfaced with a tighten-to-pointer nudge.

- [ ] **Step 4: Commit.**

```bash
git add scaffold-dev/tests/test-e2e.sh scaffold-dev/evals/closing-vertical-slice.md
git commit -m "test(scaffold-dev): re-point harvest e2e + evals to agent-read + sd_harvest_apply contract (#52, #48 Part F)"
```

---

## Phase B — Seam #7 (verifying-spec-citations, new skill)

### Task 6: Add `lib/citations.sh` mechanical legs (TDD)

**Files:**
- Create: `scaffold-dev/lib/citations.sh`
- Create: `scaffold-dev/tests/test-citations.sh`

- [ ] **Step 1: Write the failing tests** in `tests/test-citations.sh` (mirror the harness header of `tests/test-harvest.sh` — source `_helpers.sh`, `manifest.sh`, `citations.sh`; define `assert_eq`; set up a temp dir):

```bash
test_check_file_present() {
  local d; d="$(mktemp -d)"; : > "$d/real.py"
  sd_citations_check_file "$d/real.py" >/dev/null
  assert_eq "$?" "0" "existing file resolves"
}
test_check_file_absent() {
  local d; d="$(mktemp -d)"
  sd_citations_check_file "$d/missing.py" >/dev/null
  assert_eq "$?" "1" "missing file flagged"
}
test_check_signature_present() {
  local d; d="$(mktemp -d)"; printf 'def foo(a, b):\n    pass\n' > "$d/m.py"
  sd_citations_check_signature "$d/m.py" 'def foo(a, b):' >/dev/null
  assert_eq "$?" "0" "exact signature matches"
}
test_check_signature_drifted() {
  local d; d="$(mktemp -d)"; printf 'def foo(a, b, c=False):\n    pass\n' > "$d/m.py"
  sd_citations_check_signature "$d/m.py" 'def foo(a, b):' >/dev/null
  assert_eq "$?" "1" "paraphrased signature flagged"
}
```

- [ ] **Step 2: Run to verify fail.**

Run: `cd scaffold-dev && bash tests/test-citations.sh`
Expected: FAIL — functions undefined.

- [ ] **Step 3: Implement** `lib/citations.sh`:

```bash
#!/usr/bin/env bash
# scaffold-dev/lib/citations.sh
# Mechanical legs of verifying-spec-citations (#7). Semantic legs (REQ-ID denotes
# the same requirement? ARCH §-ref still points at the right content?) are the
# agent's — they are NOT in this file.
set -u

_SD_CIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_CIT_DIR/_helpers.sh"
fi

# sd_citations_check_file <path> — return 0 if the file exists, else 1 (logs).
sd_citations_check_file() {
  local p="$1"
  if [[ -f "$p" ]]; then return 0; fi
  sd_log_warn "citation: file not found: $p"
  return 1
}

# sd_citations_check_signature <file> <signature> — return 0 if <file> contains
# the exact <signature> literal (grep -F), else 1 (logs). Catches paraphrase drift.
sd_citations_check_signature() {
  local file="$1" sig="$2"
  if [[ ! -f "$file" ]]; then sd_log_warn "citation: signature host missing: $file"; return 1; fi
  if grep -Fq -- "$sig" "$file"; then return 0; fi
  sd_log_warn "citation: signature not found verbatim in $file: $sig"
  return 1
}
```

- [ ] **Step 4: Run to verify pass.**

Run: `cd scaffold-dev && bash tests/test-citations.sh`
Expected: PASS — all four cases green.

- [ ] **Step 5: Commit.**

```bash
git add scaffold-dev/lib/citations.sh scaffold-dev/tests/test-citations.sh
git commit -m "feat(scaffold-dev): add lib/citations.sh mechanical citation legs (#7)"
```

### Task 7: Author the `verifying-spec-citations` skill body

**Files:**
- Create: `scaffold-dev/skills/verifying-spec-citations/SKILL.md`

- [ ] **Step 1: Write the frontmatter** (gerund name; skill-only, no slash command — match `validating-master-spec` shape):

```markdown
---
name: verifying-spec-citations
description: Verify that the citations in a draft vertical-slice spec resolve — file paths and quoted function signatures via deterministic checks, REQ-ID and ARCH §-ref denotation via agent judgment. Use this when the user wants to verify spec citations, check a draft spec for citation drift, asks "do the REQ-IDs / file paths / signatures in this spec still resolve?", or before locking a slice spec. Read-only — never edits the spec. Manifest-routed. Skill-only invocation; no dedicated slash command.
---
```

- [ ] **Step 2: Write the body** with short, actionable sections:
  - Purpose.
  - Mechanical/agent split table.
  - How to extract each citation class from the draft spec.
  - How to run the mechanical legs: `sd citations_check_file` for file paths in Markdown prose/lists/code blocks resolved through the manifest, and `sd citations_check_signature` for quoted signatures.
  - How to judge semantic classes: REQ-ID still denotes the same requirement after renumber; ARCH §-ref title still matches after rename — quote the cited section title and compare.
  - Per-project configurable REQ-ID / ARCH regexes with graceful degradation: absent config → run mechanical legs + note that REQ/ARCH judgment was skipped without a REQ-ID scheme.
  - A `file:line` drift report so the user fixes without re-grepping.
  - The read-only guarantee.
  - A worked example surface: one resolved-clean report and one 2-drift report.
  - Mirror the structural conventions of `validating-master-spec`: single authoritative output, no auto-fix.

- [ ] **Step 3: Lint the skill** — confirm frontmatter parses and the description triggers are concrete.

Run: `grep -c '^name:\|^description:' scaffold-dev/skills/verifying-spec-citations/SKILL.md`
Expected: `2`.

- [ ] **Step 4: Commit.**

```bash
git add scaffold-dev/skills/verifying-spec-citations/SKILL.md
git commit -m "feat(scaffold-dev): add verifying-spec-citations skill (#7)"
```

### Task 8: Wire the opt-in citation check into `planning-vertical-slice` §6.4

**Files:**
- Modify: `scaffold-dev/skills/planning-vertical-slice/SKILL.md` (insert §6.4 after §6.3 gate-2 grill-me, before §7 architect-critic)

- [ ] **Step 1:** Add a new subsection §6.4 (opt-in, default no — mirroring the gate-2 grill-me offer shape):

> ### 6.4 Spec-citations check (gate, opt-in)
>
> After specs are written (and gate-2 grill-me has settled), offer the citation check **before** architect-critic so drift surfaces first:
>
> > Specs authored (N work items). Want to verify spec citations (file paths, function signatures, REQ-IDs, ARCH §-refs) before adversarial review? (yes/no, default no)
>
> - **yes** → invoke `Skill(scaffold-dev:verifying-spec-citations)` over each `work-N.NN-*/spec.md`. Drift reports may produce edits; re-write affected `spec.md` files via `sd_render`, then continue to §7.
> - **no** → skip silently and continue to §7.
>
> The check is enrichment, not a contract — never block slice planning on its absence or on a project without a REQ-ID scheme.

- [ ] **Step 2:** Update the §1 Overview numbered flow to mention the new opt-in citation gate between "Offer grill-me on specs (gate 2)" and "Invoke architect-critic" (renumber the trailing list items if they are explicitly numbered).

- [ ] **Step 3:** Confirm the planning-vertical-slice eval (if it pins the §6→§7 sequence) still holds — the citation gate is opt-in and default-skip, so the default path is unchanged. Update the eval only if it asserts an exhaustive subsection list.

Run: `cd scaffold-dev && bash tests/test-e2e.sh`
Expected: PASS (default path skips the new gate).

- [ ] **Step 4: Commit.**

```bash
git add scaffold-dev/skills/planning-vertical-slice/SKILL.md
git commit -m "feat(scaffold-dev): wire opt-in spec-citations gate into planning-vertical-slice (#7)"
```

---

## Phase C — Seam #5 (pre-flight RED-tests gate)

### Task 9: Add the `sd_redgate_assert_red` mechanical helper (TDD)

**Files:**
- Modify: `scaffold-dev/lib/verify.sh`
- Test: `scaffold-dev/tests/test-verify.sh`

- [ ] **Step 1: Write the failing tests** (append to `tests/test-verify.sh`, register in the runner):

```bash
test_redgate_red_command() {
  # A command that exits non-zero is RED (gate-pass) → return 0
  sd_redgate_assert_red 'false'
  assert_eq "$?" "0" "failing command is RED"
}
test_redgate_green_command() {
  # A command that exits 0 is already GREEN before work → gate-fail → return 1
  sd_redgate_assert_red 'true'
  assert_eq "$?" "1" "passing command is not RED"
}
test_redgate_errored_command() {
  # A command that cannot run (127) is an ERROR, not RED → return 2 (surface)
  sd_redgate_assert_red 'this_binary_does_not_exist_xyz'
  assert_eq "$?" "2" "uninvocable command is an error, not RED"
}
```

- [ ] **Step 2: Run to verify fail.**

Run: `cd scaffold-dev && bash tests/test-verify.sh`
Expected: FAIL — `sd_redgate_assert_red` undefined.

- [ ] **Step 3: Implement** in `lib/verify.sh`:

```bash
# sd_redgate_assert_red <command> [expected]
# Pre-flight RED-gate mechanical leg (#5): run <command> and classify whether
# the AC's expected predicate is already satisfied.
#   predicate NOT met             → RED (desired pre-flight state)   → return 0
#   predicate met                 → already GREEN before any work    → return 1
#   exit 126/127                  → ERROR (harness broken, not RED)  → return 2
# If [expected] is omitted, defaults to "exit 0" for backward compatibility.
sd_redgate_assert_red() {
  local cmd="${1:-}" expected="${2:-exit 0}" output rc=0
  if [[ -z "$cmd" ]]; then
    sd_log_error "sd_redgate_assert_red: command cannot be empty"
    return 2
  fi
  if output="$(bash -c "$cmd" 2>&1)"; then rc=0; else rc=$?; fi
  case "$rc" in
    126|127) return 2 ;;
  esac
  case "$expected" in
    "exit "*)
      local code="${expected#exit }"
      if [[ ! "$code" =~ ^[0-9]+$ ]]; then
        sd_log_error "sd_redgate_assert_red: invalid exit code in expected form: $expected"
        return 2
      fi
      if [[ "$rc" -eq "$code" ]]; then return 1; fi
      ;;
    "output contains "*)
      local needle="${expected#output contains }"
      if echo "$output" | grep -qF -- "$needle"; then return 1; fi
      ;;
    *)
      sd_log_error "sd_redgate_assert_red: unknown expected form: $expected"
      return 2
      ;;
  esac
  return 0
}
```

- [ ] **Step 4: Run to verify pass.**

Run: `cd scaffold-dev && bash tests/test-verify.sh`
Expected: PASS — all three cases green.

- [ ] **Step 5: Commit.**

```bash
git add scaffold-dev/lib/verify.sh scaffold-dev/tests/test-verify.sh
git commit -m "feat(scaffold-dev): add sd_redgate_assert_red pre-flight gate helper (#5)"
```

### Task 10: Add the §3.6 pre-flight RED-gate to `executing-work-item`

**Files:**
- Modify: `scaffold-dev/skills/executing-work-item/SKILL.md` (insert §3.6 after §3.5; update §4 lead-in)

- [ ] **Step 1:** After §3.5 (branch on pre-flight outcome), insert §3.6 — runs only when §3.5 says "proceed to §4":

> ### 3.6 Pre-flight RED-gate (mandatory before §4 GREEN work)
>
> Before writing **any** implementation, prove every `auto:` AC starts RED — so completing the work item is a RED→GREEN flip, not impl-first-tests-after.
>
> 1. From the `(ac_label, command, expectation)` tuples (§3.2), **classify** each AC (agent judgment): *test-command-bearing*, *grep-shaped*, or *no-runnable-command* (e.g. a pure code-deletion AC with no failing test).
> 2. For each command-bearing AC, run its command through `sd_redgate_assert_red` from inside the worktree, passing the parsed expectation:
>    ```bash
>    cd "<worktree-abs-path>" && sd_redgate_assert_red "$command" "$expectation"
>    ```
>    - return 0 → RED ✓ (expected).
>    - return 1 → **already GREEN before any work** → the AC is satisfied by current state (feature exists / AC mis-specified). Surface this; do NOT silently proceed.
>    - return 2 → **command errored / uninvocable** (broken harness or not-yet-authored test) → surface as a non-blocking advisory unless the spec says the harness must already exist; this is NOT a RED pass.
> 3. **Gate:** if any command-bearing AC is already GREEN (return 1), do NOT enter §4. Surface the offending AC(s) and stop for the user/orchestrator. RED (0) and errored/uninvocable (2) proceed, with errored cases recorded in the report.
> 4. **Skip-escape:** for a slice that legitimately has no failing test (e.g. pure code-deletion), the first run returns gaps-mode naming the already-GREEN AC. The orchestrator/user may approve `--allow-skip-thrust-zero` by recording an explicit clarification in the handoff and re-dispatching. On re-dispatch, record the skip in `report.md` §6. Never auto-skip from the flag alone.

- [ ] **Step 2:** Update the §4 lead-in sentence to reference the gate: "Per §3.6 every non-skipped `auto:` AC has been verified RED (or an explicit thrust-0 skip recorded and excluded). Now flip each remaining AC to GREEN…".

- [ ] **Step 3:** Update §3.5's "proceed to §4" branch to say "proceed to **§3.6 RED-gate**, then §4".

- [ ] **Step 4:** Confirm the skill still reads coherently for both Mode A (standalone `/work-item`) and Mode B (subagent) — the gate runs bash commands (allowed; the §6.1 denylist only excludes git-write + Task), so it is valid in subagent context.

- [ ] **Step 5: Commit.**

```bash
git add scaffold-dev/skills/executing-work-item/SKILL.md
git commit -m "feat(scaffold-dev): add §3.6 pre-flight RED-tests gate + thrust-0 skip-escape (#5)"
```

### Task 11: Add the RED-gate eval scenario (both modes)

**Files:**
- Modify: `scaffold-dev/evals/executing-work-item.md`

- [ ] **Step 1:** Add a scenario asserting: given a spec whose `auto:` ACs all start RED, the tool-call log shows the §3.6 RED-gate running each AC command **before** any source `Write`/`Edit` in §4. Assert for **both** standalone and subagent modes (the file already contracts four scenarios across both modes — follow that structure).

- [ ] **Step 2:** Add a negative scenario: an AC whose command is already GREEN pre-work → the run halts at §3.6 and surfaces the AC, with no §4 implementation edits in the log.

- [ ] **Step 3:** Add an error-path scenario: an AC command that errors (exit 126/127) → surfaced as a non-blocking advisory, NOT treated as RED and NOT a hard-block.

- [ ] **Step 4:** Add a thrust-0 scenario: a pure-deletion slice → first pass returns gaps-mode; after the orchestrator records an explicit handoff clarification and re-dispatches with `--allow-skip-thrust-zero`, the skip is recorded in `report.md` §6.

- [ ] **Step 5: Commit.**

```bash
git add scaffold-dev/evals/executing-work-item.md
git commit -m "test(scaffold-dev): add RED-gate eval scenarios, both modes (#5)"
```

---

## Phase D — Release (version, changelog, ledger, gate)

### Task 12: Version bump (both plugin.json), CHANGELOG, program ledger, full-suite + parity gate

**Files:**
- Modify: `scaffold-dev/.claude-plugin/plugin.json`
- Modify: `scaffold-dev/.codex-plugin/plugin.json`
- Modify: `scaffold-dev/CHANGELOG.md`
- Modify: `docs/agent-driven-program/SPEC-agent-driven-program.md` (§5 SS-4 + §6 ledger rows)

- [ ] **Step 1:** Bump `"version"` `0.3.0` → `0.4.0` in **both** `scaffold-dev/.claude-plugin/plugin.json` and `scaffold-dev/.codex-plugin/plugin.json` (identical).

- [ ] **Step 2:** Add a `## [0.4.0]` CHANGELOG section (Keep-a-Changelog): **Removed** — orphaned semantic harvest parsers (`sd_harvest_reports`/`sd_harvest_handoffs`/`_sd_harvest_extract_section`); **Changed** — harvest is agent-sole-reader with `sd_harvest_apply` as the single mechanical write authority (#52); report Suggestions section marked agent-read; **Added** — `sd_harvest_lint_length` lean-index leg + harvest §9.4 restate-prevention (#48 Part F), `verifying-spec-citations` skill + `lib/citations.sh` + opt-in planning gate (#7), §3.6 pre-flight RED-tests gate + `sd_redgate_assert_red` + thrust-0 skip-escape (#5).

- [ ] **Step 3:** Update `SPEC-agent-driven-program.md`: mark the §6 ledger rows for #52/#7/#5 and #48-Part-F as shipped (SS-4, scaffold-dev v0.4.0); in the §5 SS-4 entry, record the **delete-semantic-bash override** of the "labeled fallback" wording. Note #48 stays open for C/D/E + routing remainder.

- [ ] **Step 4: Run the full scaffold-dev suite (backgrounded, generous timeout).**

Run: `cd scaffold-dev && bash run-tests.sh`
Expected: PASS — all files green (harvest, citations, verify, e2e included).

- [ ] **Step 5: Run the dual-publish parity guard.**

Run: `bash tests/test-codex-dual-publish.sh`
Expected: PASS — both plugin.json at 0.4.0, frontmatter parity holds.

- [ ] **Step 6: Residue sweep.**

Run: `grep -rn 'sd_harvest_reports\|sd_harvest_handoffs\|_sd_harvest_extract_section' scaffold-dev | grep -v CHANGELOG`
Expected: no matches.

- [ ] **Step 7: Commit.**

```bash
git add scaffold-dev/.claude-plugin/plugin.json scaffold-dev/.codex-plugin/plugin.json scaffold-dev/CHANGELOG.md docs/agent-driven-program/SPEC-agent-driven-program.md
git commit -m "release(scaffold-dev): v0.4.0 — SS-4 agent-review of verification seams (#52, #7, #5, #48 Part F)"
```

---

## Post-plan (orchestrator, outside the task loop)

- Open PR `feat/ss4-agent-review-seams` → `main`; title references SS-4 + the four issues.
- Run the Codex/CodeRabbit bot-review cycle; converge on Codex-clean + green suite (per the bot-review-convergence judgment memory). Pay special attention to the **upgrade/legacy-input class** (e.g. an existing `report.md` with the *old* `- target_file:/suggestion:` bullet shape must still be read fine by the agent path) — feed that legacy shape in a test per the "test the upgrade input class" memory.
- On merge: squash, tag `scaffold-dev-v0.4.0`, close #52 / #7 / #5; comment on #48 that Part F shipped and C/D/E + routing remain.
- Write the session handoff (`/handoff`).
