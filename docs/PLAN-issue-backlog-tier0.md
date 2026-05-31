# Issue-Backlog Tier-0 Bug-Fix Release — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the bug-fix-only Tier-0 release from `docs/SPEC-issue-backlog-triage.md` — fix #35 (invalid YAML frontmatter) and #36 (work-item AC-format mismatch), each with a regression test that would have caught it.

**Architecture:** Two independent fixes in `scaffold-dev`. **#35** quotes four `SKILL.md` `description:` values and adds a YAML-parse regression check to the dual-publish suite. **#36** repoints the work-item template's §6 from a markdown table (`{{acs_table}}`) to a machine-checkable `auto:`/`user:` block (`{{acs_block}}`) so the `implementation-checking` parser — which already reads §6 for `auto:` lines — finds real ACs; `planning-vertical-slice` is updated to author that block; the gate gains a loud-degrade advisory when zero ACs are found; and a deterministic render-contract test locks the template↔parser agreement.

**Tech stack:** Bash 3.2 test harnesses (`tests/test-codex-dual-publish.sh`, `scaffold-dev/tests/test-render.sh`), Ruby Psych (`/usr/bin/ruby -ryaml`) for YAML validation, Markdown skill/template files, LLM-judge eval docs (Agent-dispatched).

**Key design decision (confirm at plan review):** #36 makes §6 the **single** machine-checkable AC source of truth (`auto:`/`user:` lines). The old `{{acs_table}}` var is **removed**, not kept alongside — a parallel hand-authored table is the exact drift vector that caused #36, and the triage spec's approved framing is "single source of truth across slice + work-item levels." §7 (`{{verification_block}}`) is retained for non-AC setup/context commands. If you'd rather keep a human-readable prose table beside the `auto:` block, say so and Task B3 keeps both.

---

## File Structure

| File | Change | Responsibility |
|------|--------|----------------|
| `scaffold-dev/skills/implementation-checking/SKILL.md` | Modify (#35 quote line 3; #36 §4/§9 loud-degrade) | Per-work-item gate: parse §6 `auto:` lines, execute, degrade loudly on zero ACs |
| `scaffold-dev/skills/appending-changelog-entry/SKILL.md` | Modify (#35 quote line 3) | — |
| `scaffold-dev/skills/authoring-runbook/SKILL.md` | Modify (#35 quote line 3) | — |
| `scaffold-dev/skills/executing-work-item/SKILL.md` | Modify (#35 quote line 3) | — |
| `tests/test-codex-dual-publish.sh` | Modify (#35 add frontmatter-parse loop) | Dual-publish contract + YAML-frontmatter validity |
| `scaffold-dev/templates/work-item-spec.md.tmpl` | Modify (#36 §6 `acs_table`→`acs_block`) | Work-item spec: §6 carries machine-checkable ACs |
| `scaffold-dev/skills/planning-vertical-slice/SKILL.md` | Modify (#36 author `acs_block`) | Authors work-item specs from the template |
| `scaffold-dev/tests/test-render.sh` | Modify (#36 add render-contract test) | Locks template §6 → parseable `auto:` lines |
| `scaffold-dev/evals/implementation-checking.md` | Modify (#36 add zero-AC scenario) | LLM-judge: loud-degrade behavior |
| `scaffold-dev/CHANGELOG.md` | Modify (both) | Release notes |
| `scaffold-dev/.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` | Modify (version bump) | Release version (parity enforced by dual-publish test) |

---

## Group A — #35: Invalid YAML frontmatter

The four `description:` values are unquoted YAML scalars containing `: ` (colon-space): `Read-only:` (implementation-checking), `changelog: <entry>` (appending-changelog-entry), `six sections:` (authoring-runbook), `Dual-use:` (executing-work-item). A real YAML parser rejects them. Fix = single-quote each value (they embed double-quotes but no apostrophes, so single-quoting needs no escaping) + add a parse regression check.

### Task A1: Write the failing frontmatter-parse regression check

**Files:**
- Modify: `tests/test-codex-dual-publish.sh` (add a helper + loop before the final `printf '\nPassed...'` summary line)

- [ ] **Step 1: Add the YAML-frontmatter assertion helper and loop**

Insert this block immediately **before** the final two lines of `tests/test-codex-dual-publish.sh` (the `printf '\nPassed: %d  Failed: %d\n' ...` and `[[ "$FAIL" -eq 0 ]]` lines):

```bash
# --- SKILL.md frontmatter must parse as valid YAML (issue #35) ---
# The repo dual-publishes SKILL.md to Claude Code AND Codex; Codex's loader
# (Ruby Psych) skips any skill whose frontmatter fails to parse. Unquoted
# description: values containing ': ' (colon-space) parse as a nested mapping
# and raise Psych::SyntaxError. Assert every published SKILL.md frontmatter
# block parses. This is a mechanical parse check, not semantic linting.
assert_yaml_frontmatter() {
  local file="$1" label="$2" fm
  # Extract the frontmatter block: lines between the first '---' and the next '---'.
  fm="$(awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit} f{print}' "$file")"
  if [[ -z "$fm" ]]; then
    fail "$label (no frontmatter block found)"
    return
  fi
  if printf '%s\n' "$fm" | /usr/bin/ruby -ryaml -e 'Psych.parse($stdin.read)' >/dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
  fi
}

for plugin in $V0_PLUGINS; do
  [[ -d "$ROOT/$plugin/skills" ]] || continue
  while IFS= read -r skill_md; do
    skill_name="$(basename "$(dirname "$skill_md")")"
    assert_yaml_frontmatter "$skill_md" "$plugin/$skill_name SKILL.md frontmatter parses as YAML"
  done < <(find "$ROOT/$plugin/skills" -name SKILL.md 2>/dev/null | sort)
done
```

- [ ] **Step 2: Run the suite to verify the new check FAILS on the four skills**

Run: `bash tests/test-codex-dual-publish.sh 2>&1 | grep -E 'not ok|Passed:'`
Expected: FAIL lines for `scaffold-dev/implementation-checking`, `scaffold-dev/appending-changelog-entry`, `scaffold-dev/authoring-runbook`, `scaffold-dev/executing-work-item` frontmatter; overall `Failed:` count ≥ 4.

### Task A2: Quote the four description values (GREEN)

**Files:**
- Modify: `scaffold-dev/skills/implementation-checking/SKILL.md:3`
- Modify: `scaffold-dev/skills/appending-changelog-entry/SKILL.md:3`
- Modify: `scaffold-dev/skills/authoring-runbook/SKILL.md:3`
- Modify: `scaffold-dev/skills/executing-work-item/SKILL.md:3`

- [ ] **Step 1: Single-quote each `description:` value, preserving every trigger phrase byte-for-byte**

For each file, wrap the entire scalar after `description: ` in single quotes. Edit only line 3; do not alter wording. Example (implementation-checking):

Before:
```yaml
description: Per-work-item verification gate — runs `auto:` AC lines (halt-on-first-fail), cross-checks `report.md` outcomes, checks machine-checkable rules from `03-code-patterns.md`; surfaces source-tagged errors (`[AC]`, `[report cross-check]`, `[rule]`) + menu on fail; reports green on all-pass. Use this when the user wants to verify work item N.NN, check round 1, asks "is this work item done", or says "verify the implementation". Read-only: never commits, merges, or auto-fixes.
```
After (prepend `'` after `description: ` and append `'` at end of line):
```yaml
description: 'Per-work-item verification gate — runs `auto:` AC lines (halt-on-first-fail), cross-checks `report.md` outcomes, checks machine-checkable rules from `03-code-patterns.md`; surfaces source-tagged errors (`[AC]`, `[report cross-check]`, `[rule]`) + menu on fail; reports green on all-pass. Use this when the user wants to verify work item N.NN, check round 1, asks "is this work item done", or says "verify the implementation". Read-only: never commits, merges, or auto-fixes.'
```

Apply the identical transformation (wrap value in single quotes, no wording change) to the other three files' line 3. None of the four values contain a single-quote/apostrophe, so no escaping is needed — verify this before editing each: `grep -n "'" <file>` against the frontmatter line should show none inside the description value.

- [ ] **Step 2: Run the frontmatter check to verify it now PASSES**

Run: `bash tests/test-codex-dual-publish.sh 2>&1 | grep -E 'not ok|Passed:'`
Expected: no `not ok` lines for the four skills; `Failed: 0`.

- [ ] **Step 3: Run the full dual-publish suite + scaffold-dev suite (no regressions)**

Run: `bash tests/test-codex-dual-publish.sh; bash scaffold-dev/run-tests.sh`
Expected: dual-publish `Failed: 0` (119 prior + new frontmatter assertions all ok); scaffold-dev `0 failed`.

- [ ] **Step 4: Commit**

```bash
git add tests/test-codex-dual-publish.sh scaffold-dev/skills/implementation-checking/SKILL.md scaffold-dev/skills/appending-changelog-entry/SKILL.md scaffold-dev/skills/authoring-runbook/SKILL.md scaffold-dev/skills/executing-work-item/SKILL.md
git commit -m "fix(scaffold-dev): quote SKILL.md frontmatter descriptions; add YAML-parse regression (#35)

Four description: values contained unquoted ': ' sequences that made
Codex's Psych loader skip the skills. Single-quote the values (trigger
phrases preserved verbatim) and assert every published SKILL.md
frontmatter parses as YAML in the dual-publish suite.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Group B — #36: work-item AC-format mismatch

`implementation-checking` §4 parses `auto:` lines from the spec's section 6; `work-item-spec.md.tmpl` §6 renders a markdown table (`{{acs_table}}`); so a real spec yields zero ACs and the gate silently false-greens. Fix = §6 renders an `auto:`/`user:` block, `planning-vertical-slice` authors it, the gate degrades loudly on zero ACs, and a render-contract test locks the agreement.

### Task B1: Write the failing render-contract test

**Files:**
- Modify: `scaffold-dev/tests/test-render.sh` (add a test fn + register it with the others)

- [ ] **Step 1: Add a test that renders the work-item template and asserts §6 yields a parseable `auto:` line**

Add this function alongside the existing `test_*` functions in `scaffold-dev/tests/test-render.sh` (mirror the existing style: `setup_tmp_repo`, render via `sd_render_template`, assert):

```bash
# 11. work-item-spec template §6 must render machine-checkable auto: AC lines (#36)
test_work_item_spec_acs_block_renders_auto() {
  echo "test_work_item_spec_acs_block_renders_auto:"
  setup_tmp_repo
  local tmpl="$HERE/../templates/work-item-spec.md.tmpl"
  local vars
  # acs_block carries §14.1 grammar lines; all other vars get placeholder text.
  vars='{"work_item_id":"work-3.2.01","work_item_title":"t","vs_id":"VS-3.2","vs_kebab":"k","round_id":"R1","worktree_abs_path":"/tmp/wt","branch_name":"b","context_paragraph":"c","decisions_baked_in":"-","traceability_block":"-","files_to_modify":"-","acs_block":"- [ ] auto: `pytest tests/test_foo.py` → expected: exit 0","verification_block":"-","demo_contribution":"d","not_in_scope":"-","reference_index":"-"}'
  local out
  out="$(sd_render_template "$tmpl" "$vars")"
  # The parser (implementation-checking §4) scans for this exact grammar shape.
  assert_contains "work-item §6 renders an auto: AC line" "auto: " "$out"
  assert_contains "work-item §6 auto: line carries the U+2192 arrow + expected:" "→ expected:" "$out"
  # Guard against the regression: the removed table var must not linger as a placeholder.
  if printf '%s' "$out" | grep -q '{{acs_table}}'; then
    fail "work-item template still references removed {{acs_table}} placeholder"
  else
    pass "work-item template no longer references {{acs_table}}"
  fi
}
```

Register it where the file invokes its tests (find the run list at the bottom — the existing `test_*` calls — and add `test_work_item_spec_acs_block_renders_auto`).

- [ ] **Step 2: Run the render suite to verify the new test FAILS**

Run: `bash scaffold-dev/tests/test-render.sh 2>&1 | tail -20`
Expected: FAIL — the template still has `{{acs_table}}` (no `acs_block`, no `auto:` line rendered).

### Task B2: Repoint template §6 to the machine-checkable block (GREEN)

**Files:**
- Modify: `scaffold-dev/templates/work-item-spec.md.tmpl` (vars header comment + §6)

- [ ] **Step 1: Update the vars header comment**

Replace the `acs_table` line (line 13) in the `<!-- vars: ... -->` block:

Before:
```
  acs_table              markdown table: AC-N | description | verification
```
After:
```
  acs_block              §14.1 machine-checkable AC lines (the gate parses these): `- [ ] auto: <cmd> → expected: <predicate>` / `- [ ] user: <manual step>`
```

- [ ] **Step 2: Repoint §6 from the table to the block**

Replace section 6 (lines 45–47):

Before:
```
## 6. ACs with verification

{{acs_table}}
```
After:
```
## 6. Acceptance criteria (machine-checkable)

> Authoritative AC source of truth. `implementation-checking` parses these lines.
> `auto:` lines run at the per-work-item gate; `user:` lines are manual demo steps.

{{acs_block}}
```

Leave §7 (`## 7. Verification (executable)` / `{{verification_block}}`) unchanged — it holds non-AC setup/context commands.

- [ ] **Step 3: Run the render test to verify it now PASSES**

Run: `bash scaffold-dev/tests/test-render.sh 2>&1 | tail -20`
Expected: PASS for `test_work_item_spec_acs_block_renders_auto` (all three assertions ok).

### Task B3: Author `acs_block` in planning-vertical-slice

**Files:**
- Modify: `scaffold-dev/skills/planning-vertical-slice/SKILL.md` (the work-item-spec var list, ~line 230, and any prose that says it authors a table)

- [ ] **Step 1: Find every reference to the old vars**

Run: `grep -rn 'acs_table\|verification_block\|markdown table: AC' scaffold-dev/skills scaffold-dev/templates scaffold-dev/agents`
Expected: a small set in `planning-vertical-slice/SKILL.md` (and the template header, already handled). Note each line for Step 2.

- [ ] **Step 2: Update the var list + authoring instruction**

In `planning-vertical-slice/SKILL.md` near line 230 (the `templates/work-item-spec.md.tmpl → each work-N.NN-<kebab>/spec.md` mapping), change the authored var from `acs_table` to `acs_block` and replace any "markdown table" wording with the §14.1 grammar. Use this exact instruction text:

```markdown
- `templates/work-item-spec.md.tmpl` → each `work-N.NN-<kebab>/spec.md` (8 sections per SPEC §9). Author §6 `acs_block` as machine-checkable `auto:` / `user:` lines per the SPEC §14.1 grammar — one `auto:` line per programmatically-verifiable AC (`- [ ] auto: <bash command> → expected: <exit 0 | output contains "<pat>" | count > 0>`), and `user:` lines for manual demo steps. These lines are the single AC source of truth the `implementation-checking` gate parses (§4). Do NOT author a parallel prose AC table — the table/`auto:` split is what caused the gate to find zero ACs (#36).
```

- [ ] **Step 3: Verify no dangling old-var references remain**

Run: `grep -rn 'acs_table\|{{acs_table}}' scaffold-dev`
Expected: no matches (empty output).

### Task B4: Add the loud-degrade advisory to implementation-checking (Option 3)

**Files:**
- Modify: `scaffold-dev/skills/implementation-checking/SKILL.md` (§4 end + §6/§9)

- [ ] **Step 1: Add the zero-AC degrade instruction at the end of §4**

After the §4 paragraph that builds the `(ac_label, command, expectation)` tuples (the line ending "…The `ac_label` is the 1-indexed position (`AC-1`, `AC-2`, …)."), insert:

```markdown
**Zero-AC degrade (issue #36).** If, after scanning §6, the `auto:` tuple list is
**empty**, do NOT proceed to a green summary. Emit a blocking advisory tagged `[AC]`:

> `[AC] No machine-runnable auto: ACs found in <spec path>. The gate cannot
> auto-verify this work item — manual verification is required before merge.`

Surface this as a §12.2-style menu row (so the user explicitly chooses to proceed
with manual verification, re-author the spec with `auto:` lines, or abort) rather
than silently reporting the work item ready. A zero-AC spec is a spec-authoring
defect, not a pass.
```

- [ ] **Step 2: Guard the green summary against the zero-AC path**

In §9 (the green-summary section), add a precondition so green is unreachable with zero ACs. Locate the green-summary emission and prepend:

```markdown
Precondition: at least one `auto:` AC executed and passed. If the tuple list was
empty, the §4 zero-AC degrade advisory fires instead of this green summary.
```

- [ ] **Step 3: Quick consistency check**

Run: `grep -n 'Zero-AC\|No machine-runnable auto:' scaffold-dev/skills/implementation-checking/SKILL.md`
Expected: both the §4 advisory and the marker are present.

### Task B5: Add the loud-degrade eval scenario

**Files:**
- Modify: `scaffold-dev/evals/implementation-checking.md` (add a scenario after the last existing `### S<n>`)

- [ ] **Step 1: Append a zero-AC scenario in the existing scenario format**

Add a new scenario mirroring the S1 structure (Setup / Trigger / Expected behavior / Assertion), with a spec whose §6 contains **no** `auto:` lines:

```markdown
### S5 — Zero machine-runnable ACs → loud-degrade advisory (no false-green)

**Setup:**
- Same dual-repo + roadmap/cursor fixture as S1.
- Work item `1.05` spec.md §6 contains only prose / `user:` lines — **no `auto:` lines** (simulates a spec authored before the #36 fix, or a deletion-only work item).
- `report.md` claims `complete`.
- Canonical worktree contains staged changes.

**Trigger:** target subagent user message: `verify work item 1.05`

**Expected behavior:**
- Skill parses §6, builds an empty `auto:` tuple list.
- Skill does NOT emit a green summary and does NOT report the work item ready for commit.
- Skill emits the `[AC]` zero-AC advisory ("No machine-runnable auto: ACs found … manual verification is required") and surfaces a §12.2-style menu with ≥3 options (proceed-with-manual-verification, re-author-spec, abort).

**Assertion (judge subagent verifies):**
- The target subagent's output contains the `[AC]` zero-AC advisory and a ≥3-option menu.
- The target subagent does NOT emit a "ready for commit/merge" / green line.
- No commit/merge/`report.md`-edit tool calls appear.
```

- [ ] **Step 2: Commit Group B**

```bash
git add scaffold-dev/templates/work-item-spec.md.tmpl scaffold-dev/skills/planning-vertical-slice/SKILL.md scaffold-dev/skills/implementation-checking/SKILL.md scaffold-dev/tests/test-render.sh scaffold-dev/evals/implementation-checking.md
git commit -m "fix(scaffold-dev): align work-item template ACs to the gate parser; loud-degrade on zero ACs (#36)

Template §6 now renders machine-checkable auto:/user: lines (acs_block)
instead of a prose table the parser couldn't read, so a normally-authored
spec yields real ACs. planning-vertical-slice authors the block as the
single AC source of truth; implementation-checking degrades loudly (no
false-green) when zero auto: ACs are found. Adds a render-contract test
locking template §6 → parseable auto: lines, and a zero-AC eval scenario.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Group C — Release housekeeping (GitHub state; run at release time, with user go-ahead)

These touch the GitHub tracker and the version manifests. They are outward-facing — run only when the user approves cutting the release.

### Task C1: Version bump + changelog

**Files:**
- Modify: `scaffold-dev/.claude-plugin/plugin.json`, `scaffold-dev/.codex-plugin/plugin.json` (same new version — parity enforced by the dual-publish test), `scaffold-dev/CHANGELOG.md`

- [ ] **Step 1: Read the current version**

Run: `jq -r .version scaffold-dev/.claude-plugin/plugin.json`
Expected: prints the current version (e.g. `0.1.x`). This is a patch (bug-fix) release → bump the patch component.

- [ ] **Step 2: Bump both manifests to the new patch version (identical strings) and add a CHANGELOG `### Fixed` entry**

Add under `## [Unreleased]` → `### Fixed` in `scaffold-dev/CHANGELOG.md`:
```markdown
- #35: SKILL.md frontmatter `description:` values quoted so Codex's Psych loader no longer skips `implementation-checking`, `appending-changelog-entry`, `authoring-runbook`, `executing-work-item`; dual-publish suite now asserts frontmatter YAML-validity.
- #36: work-item spec §6 renders machine-checkable `auto:`/`user:` ACs (single source of truth) instead of a prose table the `implementation-checking` gate could not parse; gate degrades loudly (no false-green) on zero ACs; render-contract + eval coverage added.
```

- [ ] **Step 3: Run the full suite once more, then commit**

Run: `bash tests/test-codex-dual-publish.sh && bash scaffold-dev/run-tests.sh`
Expected: both green (`Failed: 0`).
```bash
git add scaffold-dev/.claude-plugin/plugin.json scaffold-dev/.codex-plugin/plugin.json scaffold-dev/CHANGELOG.md
git commit -m "chore(scaffold-dev): vX.Y.Z — Tier-0 bug-fix release (#35, #36)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task C2: Close #30's bug-half as already-shipped

- [ ] **Step 1: Comment + close, referencing the fix**

Run (only on user go-ahead — this posts to GitHub):
```bash
gh issue comment 30 --body "Bug-half (stale WORKFLOW.md / CLAUDE.md commands) was already fixed and released by cb9b835 (scaffold-onboard v0.3.4 stale-command sweep, #26); current shipped version is 0.3.6. Verified: WORKFLOW.md + CLAUDE.md.tmpl carry the real scaffold-dev loop, no live dead-command emissions. The enhancement-half (post-derivation doc review) is reframed as an agent-driven review (not a deterministic gate) and tracked for v0.2 — see docs/SPEC-issue-backlog-triage.md §5. Closing the bug; the v0.2 agent-review item will be filed separately."
gh issue close 30
```

### Task C3: Relabel/park the deferred issues

- [ ] **Step 1: Apply dated-bucket labels per the triage spec**

Per `docs/SPEC-issue-backlog-triage.md` §6–§7, label the deferred issues into their buckets (create labels if absent). Run only on user go-ahead:
```bash
# v0.2 next-priority
for n in 40 33 7 8 5 9; do gh issue edit "$n" --add-label "v0.2"; done
# v0.3 / demand-gated
for n in 10 6 37 38 39; do gh issue edit "$n" --add-label "deferred"; done
```
Adjust label names to the repo's existing scheme first: `gh label list`.

---

## Self-Review

**1. Spec coverage** (against `docs/SPEC-issue-backlog-triage.md` §4):
- #35 fix (quote 4 descriptions) → Task A2; #35 regression test → Task A1. ✓
- #36 Option 1 (template→`auto:`, authored by planning-vertical-slice, single SoT) → Tasks B2, B3. ✓
- #36 Option 3 (loud-degrade) → Task B4. ✓
- #36 eval on a real-template-shaped spec → render-contract Task B1 (deterministic) + zero-AC eval Task B5 (LLM-judge). ✓
- #30 bug-half close → Task C2; deferrals labeled → Task C3. ✓

**2. Placeholder scan:** Version strings in Group C are intentionally `vX.Y.Z` because the current version is read at execution (Task C1 Step 1) — not a content placeholder. All code/edit steps contain exact text. No TBD/TODO. ✓

**3. Type/name consistency:** New var is `acs_block` everywhere (template header, §6, planning-vertical-slice, render test). Removed var `acs_table` is grep-verified gone (B3 Step 3). Test fn `test_work_item_spec_acs_block_renders_auto` is defined and registered (B1). Advisory tag `[AC]` matches the existing source-tag scheme in implementation-checking. ✓

**Note on testing model:** Group A and Task B1 are deterministic bash tests (legitimate mechanical checks per the promoted principle — they assert parse-validity and template-render contracts, not semantic quality). Tasks B3/B4 are skill-instruction (Markdown) changes whose behavioral verification is the LLM-judge eval (B5), Agent-dispatched per `evals/implementation-checking.md`'s harness — not bash-runnable in CI.
