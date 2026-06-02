# SS-1 — Memory-Bank Ownership + Single-Point Update Cadence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close #45 by classifying every memory-bank file by ownership — adding two new pure-dev-authored files (`09-known-issues`, `10-decisions-log`), making `03-code-patterns`'s machine-checkable-rules zone survive re-derive, authoring a single canonical update-cadence policy that every other skill points to, rerouting slice-close harvest away from derived files, and migrating existing provenance-trailed content out of derived files.

**Architecture:** Memory-bank files split into three ownership classes — **spec-derived** (regenerated freely: `00,01,02,04,07,08,index`), **pure-dev-authored** (seeded once, preserved on re-derive: `05,06,09,10,tech-debt`), and **mixed** (`03` = derived prose + one mechanically-preserved `## Machine-checkable rules` zone). Because dev-authored learnings now live in their own preserved files, the derived files become safely regenerable with **no agent-merge engine** — the only in-place preservation is `03`'s rules zone via deterministic sentinel extract/re-inject (a non-reasoning fact → KEEP-MECH per the program north star). A single cadence policy in `WORKFLOW.md` is the only place the event×file×who rule is stated; all other skills point to it (enforced by a grep-guard on a uniqueness marker).

**Tech Stack:** Bash 3.2 (macOS-portable, BSD awk/sed), markdown templates, plugin SKILL.md prose, bash test harness (`tests/test-*.sh` + `run-tests.sh` per plugin). Cross-plugin: `scaffold-onboard` (derive/templates/policy) + `scaffold-dev` (harvest/guard).

**Plugins & key paths:**
- `scaffold-onboard/lib/memory-bank.sh` — `sf_memory_bank_derive` (bash/`--fast` derive path)
- `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md` §13 — synthesis (agent) derive path
- `scaffold-onboard/templates/memory-bank/*.tmpl` + `WORKFLOW.md` + `index.md.tmpl`
- `scaffold-onboard/templates/claude-md/CLAUDE.md.tmpl` — SSoT note + Tier-0 preload
- `scaffold-onboard/skills/authoring-machine-checkable-rules/SKILL.md` §8 — rule insertion boundary
- `scaffold-dev/lib/harvest.sh` — `sd_harvest_apply` (derived-file guard)
- `scaffold-dev/skills/closing-vertical-slice/SKILL.md` §9 + `references/memory-bank-harvest-example.md` — harvest target set

**Marker strings (fixed contract — use verbatim everywhere):**
- Preserve zone in `03`: `<!-- mcrules:preserve:start -->` … `<!-- mcrules:preserve:end -->`
- Canonical cadence policy uniqueness marker: `<!-- cadence-policy:canonical -->`
- Cadence pointer phrase (what every other skill says): `` `memory-bank/WORKFLOW.md` → **Memory-bank update cadence** ``

**Ownership classes (the spec's core; reuse these exact lists):**
- Spec-derived (regenerate): `00-project-brief 01-product-context 02-system-patterns 04-tech-context 07-constraints 08-governance index`
- Mixed (derive prose + preserve rules zone): `03-code-patterns`
- Pure-dev-authored (seed-if-missing, preserve): `05-active-context 06-progress 09-known-issues 10-decisions-log tech-debt`
- Static: `WORKFLOW.md`

---

## How to run the suites (use throughout)

```bash
# scaffold-onboard — full suite (slow: 55–75s+ per file; run with a generous timeout)
bash scaffold-onboard/run-tests.sh
# single file
bash scaffold-onboard/run-tests.sh tests/test-memory-bank.sh

# scaffold-dev — full suite
bash scaffold-dev/run-tests.sh
bash scaffold-dev/run-tests.sh tests/test-harvest.sh

# repo-level dual-publish parity (release gate)
bash tests/test-codex-dual-publish.sh
```

Per `feedback_full_suite_when_verifying_subagents`: run the WHOLE plugin suite before declaring any task green, and distrust "pre-existing failure" claims — verify against `git stash` baseline if a failure looks unrelated.

---

## Task 1 (W1): New pure-dev files `09-known-issues` + `10-decisions-log`

**Files:**
- Create: `scaffold-onboard/templates/memory-bank/09-known-issues.md.tmpl`
- Create: `scaffold-onboard/templates/memory-bank/10-decisions-log.md.tmpl`
- Modify: `scaffold-onboard/lib/memory-bank.sh` (live-seed loop in `sf_memory_bank_derive`; header comment)
- Modify: `scaffold-onboard/templates/memory-bank/index.md.tmpl` (two new rows + load tiers)
- Modify: `scaffold-onboard/templates/claude-md/CLAUDE.md.tmpl` (add `09` to Tier-0 preload)
- Modify: `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md` (§1, §4 bucket table — file counts + new live-seed files)
- Test: `scaffold-onboard/tests/test-memory-bank.sh`

Note: `09`/`10` are **live-seed** (same bucket as `05`/`06`) — they are NOT synthesized, so **no synthesis brief is needed**. They get header-only seed via the bash live-seed loop, which the synthesis path also invokes (`sf_memory_bank_derive --fast` at SKILL §13.3 end).

- [ ] **Step 1: Write failing tests for new-file seeding + preservation**

Add to `scaffold-onboard/tests/test-memory-bank.sh` (before the test-invocation list near the bottom):

```bash
# SS-1 W1 — new pure-dev files seeded header-only and preserved on re-derive.
test_new_dev_files_seeded() {
  echo "test_new_dev_files_seeded:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  assert_file_exists "./.claude/memory-bank/09-known-issues.md"
  assert_file_exists "./.claude/memory-bank/10-decisions-log.md"
  assert_file_contains "./.claude/memory-bank/09-known-issues.md" "# Known Issues"
  assert_file_contains "./.claude/memory-bank/10-decisions-log.md" "# Decisions Log"
}

test_new_dev_files_preserved_on_rederive() {
  echo "test_new_dev_files_preserved_on_rederive:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  echo "- gotcha: widgets race on startup" >> ".claude/memory-bank/09-known-issues.md"
  echo "- decided: use file-lock for the registry" >> ".claude/memory-bank/10-decisions-log.md"
  sf_memory_bank_derive
  assert_file_contains "./.claude/memory-bank/09-known-issues.md" "widgets race on startup"
  assert_file_contains "./.claude/memory-bank/10-decisions-log.md" "use file-lock for the registry"
}
```

Add their names to the invocation list (just before `report_results`):

```bash
test_new_dev_files_seeded
test_new_dev_files_preserved_on_rederive
```

Also extend the existing `test_all_derived_files_present` loop list to include the two new files. Change its `for f in ...` line to add `09-known-issues 10-decisions-log`:

```bash
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 05-active-context 06-progress 07-constraints 08-governance 09-known-issues 10-decisions-log index WORKFLOW tech-debt; do
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scaffold-onboard/run-tests.sh tests/test-memory-bank.sh`
Expected: FAIL — `09-known-issues.md` / `10-decisions-log.md` do not exist (templates + seed loop not yet added).

- [ ] **Step 3: Create the two templates**

Create `scaffold-onboard/templates/memory-bank/09-known-issues.md.tmpl`:

```markdown
# Known Issues

> Live file — dev-authored, never auto-regenerated. Caveats, gotchas, workarounds,
> and dev-discovered stack/tech notes ("things that bite / behaviors to watch").
> Promoted here by slice-close harvest and by hand. Enforceable rules do NOT go
> here — escalate them to a machine-checkable rule in `03-code-patterns.md`.
>
> Update cadence: see `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**.

## Caveats & gotchas
*(none yet)*

## Stack / tech notes
*(none yet)*
```

Create `scaffold-onboard/templates/memory-bank/10-decisions-log.md.tmpl`:

```markdown
# Decisions Log

> Live file — dev-authored, never auto-regenerated. Build-time decisions and
> advisory patterns/conventions ("things we chose / established"). Promoted here
> by slice-close harvest and by hand. ADR-worthy decisions also get a formal ADR;
> enforceable patterns escalate to a machine-checkable rule in `03-code-patterns.md`.
>
> Update cadence: see `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**.

## Decisions
*(none yet)*

## Advisory patterns & conventions
*(none yet)*
```

- [ ] **Step 4: Register both as live-seed in `sf_memory_bank_derive`**

In `scaffold-onboard/lib/memory-bank.sh`, change the live-seed loop (currently lines ~91) from:

```bash
  # 2 live files — seed only if missing (unless --force)
  for f in 05-active-context 06-progress; do
```

to:

```bash
  # 4 live files — seed only if missing (unless --force)
  for f in 05-active-context 06-progress 09-known-issues 10-decisions-log; do
```

Also update the file-header comment at the top (line 3) from:

```bash
# Memory-bank derivation: 9 derived files + 2 live (seeded once) + 1 static + 1 seeded index (tech-debt.md).
```

to:

```bash
# Memory-bank derivation: 8 derived files (00-04,07,08,index) + 4 live (05,06,09,10 — seeded once)
# + 1 static (WORKFLOW.md) + 1 seeded index (tech-debt.md). 03 keeps a preserved rules zone (SS-1 W2).
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash scaffold-onboard/run-tests.sh tests/test-memory-bank.sh`
Expected: PASS — both new tests green; `test_all_derived_files_present` still green with the two added files.

- [ ] **Step 6: Register in `index.md.tmpl` + Tier-0 preload + SKILL.md counts**

In `scaffold-onboard/templates/memory-bank/index.md.tmpl`, insert two rows immediately after the `04-tech-context.md` row (keep numeric order — `09`/`10` rows go after `08-governance.md`, before `tech-debt.md`). Add after the `08-governance.md` row:

```markdown
| `09-known-issues.md` | Caveats · gotchas · workarounds · dev-discovered stack notes | **Tier 0** · **LIVE** |
| `10-decisions-log.md` | Build-time decisions · advisory patterns / conventions | on-demand · branch · **LIVE** |
```

In `scaffold-onboard/templates/claude-md/CLAUDE.md.tmpl`, add `09-known-issues.md` to the Tier-0 preload list (after `05-active-context.md`, line ~10) so it becomes always-load (SP-4):

```markdown
- `.claude/memory-bank/09-known-issues.md`
```

In `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md`:
- §1 (Overview, line ~16): change "Two are live-seed (`05-active-context.md`, `06-progress.md`)" to "Four are live-seed (`05-active-context.md`, `06-progress.md`, `09-known-issues.md`, `10-decisions-log.md`)" and update the leading "12-file" / "Eight files come from MASTER-SPEC … Two are live-seed" sentence to reflect **14 files** (8 derived + 4 live-seed + 1 static + 1 seeded index).
- §4 bucket table (line ~54): change the Live-seed row's Files cell from `` `05-active-context`, `06-progress` (2 files) `` to `` `05-active-context`, `06-progress`, `09-known-issues`, `10-decisions-log` (4 files) ``. Update the prose "12 files, four behaviors" header and the "core 11-file" reference to **14 files**.
- §7 routing table: the line "each of the 12 files routes through this name" → "each of the 14 files routes through this name".

Note: do NOT chase every "11-file"/"12-file" string blindly — only the memory-bank count statements. The `description:` frontmatter says "12-file memory bank"; update it to "14-file memory bank".

- [ ] **Step 7: Run full scaffold-onboard suite + commit**

Run: `bash scaffold-onboard/run-tests.sh`
Expected: all files PASS (e2e test may assert file counts — if `tests/test-e2e.sh` counts memory-bank files, update its expected count from 12 to 14; grep it first: `grep -n "12\|count" scaffold-onboard/tests/test-e2e.sh`).

```bash
git add scaffold-onboard/templates/memory-bank/09-known-issues.md.tmpl \
        scaffold-onboard/templates/memory-bank/10-decisions-log.md.tmpl \
        scaffold-onboard/lib/memory-bank.sh \
        scaffold-onboard/templates/memory-bank/index.md.tmpl \
        scaffold-onboard/templates/claude-md/CLAUDE.md.tmpl \
        scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md \
        scaffold-onboard/tests/test-memory-bank.sh
git commit -m "feat(scaffold-onboard): add 09-known-issues + 10-decisions-log live-seed files (SS-1 W1, #45)"
```

---

## Task 2 (W2): `03-code-patterns` machine-checkable-rules preserved zone

**Files:**
- Modify: `scaffold-onboard/templates/memory-bank/03-code-patterns.md.tmpl` (wrap rules section in preserve sentinels)
- Modify: `scaffold-onboard/lib/memory-bank.sh` (extract/re-inject helpers + special-case `03` in derive)
- Modify: `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md` §13 (synthesis path: capture-before-dispatch, re-inject-after)
- Modify: `scaffold-onboard/templates/synthesis-briefs/03-code-patterns.brief.md` (require the sentinels verbatim)
- Modify: `scaffold-onboard/skills/authoring-machine-checkable-rules/SKILL.md` §8 (insertion boundary = `mcrules:preserve:end`)
- Test: `scaffold-onboard/tests/test-memory-bank.sh`

**Design:** The `## Machine-checkable rules` section (heading + invitation comment + any accumulated `<!-- mcrule:start -->` blocks) is wrapped in `<!-- mcrules:preserve:start -->` … `<!-- mcrules:preserve:end -->`. On every re-derive, the bash path captures the old zone, renders the template (which emits a fresh empty zone), then replaces the fresh zone with the captured one. The synthesis path does the same around the sub-agent dispatch. `## User-global defaults` stays OUTSIDE the zone (it is static derived content, re-rendered every time).

- [ ] **Step 1: Write failing test for rules-zone survival**

Add to `scaffold-onboard/tests/test-memory-bank.sh`:

```bash
# SS-1 W2 — a machine-checkable rule authored into 03 survives a plain re-derive;
# the derived prose around it still refreshes.
test_03_rules_zone_preserved_on_rederive() {
  echo "test_03_rules_zone_preserved_on_rederive:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  # Simulate authoring-machine-checkable-rules inserting a rule inside the zone.
  perl -0pi -e 's{<!-- mcrules:preserve:end -->}{<!-- mcrule:start type=banned-imports -->\nbanned: requests\n<!-- mcrule:end -->\n<!-- mcrules:preserve:end -->}' \
    ".claude/memory-bank/03-code-patterns.md"
  sf_memory_bank_derive
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "mcrule:start type=banned-imports"
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "banned: requests"
  # derived prose still present (zone is not the whole file)
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "User-global defaults"
}
```

Add `test_03_rules_zone_preserved_on_rederive` to the invocation list before `report_results`.

> If `perl` is undesirable for portability, substitute an `awk`-based insert. The test only needs to drop a rule line before the `mcrules:preserve:end` marker.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scaffold-onboard/run-tests.sh tests/test-memory-bank.sh`
Expected: FAIL — the template has no `mcrules:preserve:end` marker yet (perl substitution is a no-op), and even if it did, re-derive overwrites `03` wholesale, dropping the rule.

- [ ] **Step 3: Wrap the rules section in the template with preserve sentinels**

In `scaffold-onboard/templates/memory-bank/03-code-patterns.md.tmpl`, replace the existing block (lines ~27–33):

```markdown
## Machine-checkable rules

<!--
  Project rules live below in the HTML-sentinel `mcrule` DSL (SPEC §8.2).
  Use `/add-project-rule` (skill: authoring-machine-checkable-rules) to add
  rules; this section is intentionally seeded empty for tools that parse it.
-->
```

with (sentinels added around heading + invitation; `## User-global defaults` below stays as-is, outside the zone):

```markdown
<!-- mcrules:preserve:start -->
<!-- This zone is PRESERVED across /scaffold-project re-derive. Everything else in
     this file re-renders from MASTER-SPEC.md. Rules added here by
     authoring-machine-checkable-rules survive regeneration. See
     `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**. -->
## Machine-checkable rules

<!--
  Project rules live below in the HTML-sentinel `mcrule` DSL (SPEC §8.2).
  Use `/add-project-rule` (skill: authoring-machine-checkable-rules) to add
  rules; this section is intentionally seeded empty for tools that parse it.
-->
<!-- mcrules:preserve:end -->
```

- [ ] **Step 4: Add extract/re-inject helpers + special-case `03` in the derive loop**

In `scaffold-onboard/lib/memory-bank.sh`, add these helpers above `sf_memory_bank_derive` (after `_memory_bank_args`):

```bash
# Echo the preserved rules zone (start..end sentinels inclusive) from $1.
# Empty output if the file or the markers are absent.
_sf_mb_extract_preserve_zone() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  awk '
    /<!-- mcrules:preserve:start -->/ { cap=1 }
    cap { print }
    /<!-- mcrules:preserve:end -->/   { if (cap) exit }
  ' "$file"
}

# Replace the freshly-rendered preserve zone in $1 with the saved zone text ($2).
# Returns non-zero (and leaves $1 untouched) if $1 has no preserve markers, so the
# caller can fall back. macOS-portable (no in-place sed -i).
_sf_mb_reinject_preserve_zone() {
  local file="$1" saved="$2"
  grep -q '<!-- mcrules:preserve:start -->' "$file" || return 1
  grep -q '<!-- mcrules:preserve:end -->'   "$file" || return 1
  local tmp; tmp="$(mktemp)"
  awk -v saved="$saved" '
    /<!-- mcrules:preserve:start -->/ { print saved; skip=1; next }
    /<!-- mcrules:preserve:end -->/   { if (skip) { skip=0; next } }
    skip { next }
    { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}
```

Then change the derived-file loop so `03` is special-cased. Replace the loop (currently lines ~85–88):

```bash
  # 8 derived files
  local f
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 07-constraints 08-governance index; do
    sf_render "$tmpl_dir/${f}.md.tmpl" "${args[@]}" > ".claude/memory-bank/${f}.md"
  done
```

with:

```bash
  # 8 derived files. 03-code-patterns keeps a preserved rules zone (SS-1 W2):
  # capture the existing zone, re-render, re-inject.
  local f
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 07-constraints 08-governance index; do
    local out=".claude/memory-bank/${f}.md"
    if [[ "$f" == "03-code-patterns" ]]; then
      local saved_zone
      saved_zone="$(_sf_mb_extract_preserve_zone "$out")"
      sf_render "$tmpl_dir/${f}.md.tmpl" "${args[@]}" > "$out"
      if [[ -n "$saved_zone" ]]; then
        _sf_mb_reinject_preserve_zone "$out" "$saved_zone" \
          || sf_log_warn "03-code-patterns: could not re-inject preserved rules zone"
      fi
    else
      sf_render "$tmpl_dir/${f}.md.tmpl" "${args[@]}" > "$out"
    fi
  done
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash scaffold-onboard/run-tests.sh tests/test-memory-bank.sh`
Expected: PASS — `test_03_rules_zone_preserved_on_rederive` green. Also confirm `test_derive_seeds_machine_checkable_rules_section` still passes (the `^## Machine-checkable rules` heading is still present, now inside the zone).

- [ ] **Step 6: Thread preservation through the synthesis (agent) path**

In `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md` §13.3, expand the existing "03-code-patterns special note" (line ~311). Replace it with:

```markdown
**03-code-patterns special note (preserved rules zone — SS-1 W2):** `03` carries a
`<!-- mcrules:preserve:start -->` … `<!-- mcrules:preserve:end -->` zone that must
survive re-derive. BEFORE dispatching the `03-code-patterns` sub-agent, capture the
existing zone:

```bash
saved_zone="$(_sf_mb_extract_preserve_zone "$out_03")"   # $out_03 = resolved 03 path
```

The brief instructs the agent to emit the section wrapped in those exact sentinels
(empty: heading + invitation only). AFTER the agent returns `mode:complete` and the
file is written, re-inject the captured zone:

```bash
if [[ -n "$saved_zone" ]]; then
  _sf_mb_reinject_preserve_zone "$out_03" "$saved_zone" \
    || { sf_log_warn "03 synthesis omitted preserve markers — falling back to deterministic render"; \
         sf_render "${CLAUDE_PLUGIN_ROOT}/templates/memory-bank/03-code-patterns.md.tmpl" ... > "$out_03"; \
         _sf_mb_reinject_preserve_zone "$out_03" "$saved_zone"; }
fi
```

If the sub-agent fails to emit the sentinels, `_sf_mb_reinject_preserve_zone` returns
non-zero → fall back to the deterministic `03` render (which always has the sentinels),
then re-inject. The deterministic template is the labeled fallback, never a silent
default (program north star: one source of truth per job).
```

In `scaffold-onboard/templates/synthesis-briefs/03-code-patterns.brief.md`, add to the Synthesis guidance an explicit instruction (so the agent emits the sentinels). Append a paragraph:

```markdown
Machine-checkable rules section: emit it wrapped EXACTLY in these two HTML comment
sentinels, with the heading and invitation comment only — zero `<!-- mcrule:start -->`
blocks (rule authoring is a separate skill):

    <!-- mcrules:preserve:start -->
    ## Machine-checkable rules

    <!-- (invitation comment — keep the existing wording) -->
    <!-- mcrules:preserve:end -->

The orchestrator preserves whatever rules already exist between those sentinels across
re-derive; your job is only to emit the empty, sentinel-wrapped section.
```

Also verify the brief's `required_sections` still lists "Machine-checkable rules" (it should — leave it). The `sf_synth_assert_sections` check normalizes headings, so the wrapped heading still matches.

- [ ] **Step 7: Fix the rule-insertion boundary in authoring-machine-checkable-rules**

In `scaffold-onboard/skills/authoring-machine-checkable-rules/SKILL.md` §8, the insertion logic currently inserts "after the last `<!-- mcrule:end -->` before the next `## ` heading (or EOF)". With the preserve sentinels, new rules MUST land before `<!-- mcrules:preserve:end -->` (otherwise they fall outside the preserved zone and get clobbered on re-derive). Update §8 step 1 and step 2:

Replace step 1:

```markdown
1. **Locate the section.** Find the line matching `^## Machine-checkable rules`. In a
   scaffold-onboard-derived `03-code-patterns.md` it sits inside a preserved zone
   delimited by `<!-- mcrules:preserve:start -->` … `<!-- mcrules:preserve:end -->`
   (SS-1 W2 — that zone is what survives `/scaffold-project` re-derive; rules placed
   outside it would be lost). If the heading is absent, append the full sentinel-wrapped
   zone (start marker, heading, invitation, end marker) at EOF and treat the new block
   as the first under it.
```

Replace step 2:

```markdown
2. **Find the insertion point.** The section's lower boundary is
   `<!-- mcrules:preserve:end -->` when present (NOT the next `## ` heading — that is
   now outside the preserved zone). Search forward from the heading for the last
   `<!-- mcrule:end -->` before `<!-- mcrules:preserve:end -->`; insert the new block
   after that line, preceded by a blank line. If no `<!-- mcrule:end -->` exists yet,
   insert after the invitation comment, immediately before `<!-- mcrules:preserve:end -->`.
   (Legacy files without the preserve markers fall back to the old boundary: before the
   next `## ` heading or EOF.)
```

- [ ] **Step 8: Run full scaffold-onboard suite + commit**

Run: `bash scaffold-onboard/run-tests.sh`
Expected: all PASS — especially `test-memory-bank.sh`, `test-rules.sh`, `test-synthesis.sh`.

```bash
git add scaffold-onboard/templates/memory-bank/03-code-patterns.md.tmpl \
        scaffold-onboard/lib/memory-bank.sh \
        scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md \
        scaffold-onboard/templates/synthesis-briefs/03-code-patterns.brief.md \
        scaffold-onboard/skills/authoring-machine-checkable-rules/SKILL.md \
        scaffold-onboard/tests/test-memory-bank.sh
git commit -m "feat(scaffold-onboard): preserve 03 machine-checkable-rules zone across re-derive (SS-1 W2, #45)"
```

---

## Task 3 (W3): Single-point cadence policy in `WORKFLOW.md` + CLAUDE.md SSoT rewrite

**Files:**
- Modify: `scaffold-onboard/templates/memory-bank/WORKFLOW.md` (replace "When to update memory-bank" with THE canonical policy)
- Modify: `scaffold-onboard/templates/claude-md/CLAUDE.md.tmpl` §SSoT discipline (distinguish derived vs dev-authored; point to policy)
- Test: `scaffold-onboard/tests/test-memory-bank.sh` (assert the canonical marker + classes present)

- [ ] **Step 1: Write failing test for the canonical policy**

Add to `scaffold-onboard/tests/test-memory-bank.sh`:

```bash
# SS-1 W3 — the canonical cadence policy lives in WORKFLOW.md and carries the
# uniqueness marker; the three ownership classes are named.
test_cadence_policy_canonical() {
  echo "test_cadence_policy_canonical:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  assert_file_contains "./.claude/memory-bank/WORKFLOW.md" "cadence-policy:canonical"
  assert_file_contains "./.claude/memory-bank/WORKFLOW.md" "Memory-bank update cadence"
  assert_file_contains "./.claude/memory-bank/WORKFLOW.md" "Spec-derived"
  assert_file_contains "./.claude/memory-bank/WORKFLOW.md" "Dev-authored"
}
```

Add `test_cadence_policy_canonical` to the invocation list.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scaffold-onboard/run-tests.sh tests/test-memory-bank.sh`
Expected: FAIL — WORKFLOW.md has no `cadence-policy:canonical` marker yet.

- [ ] **Step 3: Replace the "When to update memory-bank" section in WORKFLOW.md**

In `scaffold-onboard/templates/memory-bank/WORKFLOW.md`, replace the section (lines ~24–28):

```markdown
## When to update memory-bank

- **05-active-context.md** — update as you switch slices or change focus. Hand-edit freely.
- **06-progress.md** — append after every commit (via `add changelog entry` or by hand). One line per change.
- **00–04, 07, 08, index** — never hand-edit; re-run `/scaffold-project` after editing MASTER-SPEC.md.
```

with the canonical policy:

```markdown
## Memory-bank update cadence

<!-- cadence-policy:canonical -->

> **This section is the single source of truth for when and by whom each memory-bank
> file is updated.** Every scaffold-onboard / scaffold-dev skill that touches the
> memory bank points here instead of restating the rule. Change the cadence here only.

Files fall into three ownership classes:

- **Spec-derived** — `00-project-brief`, `01-product-context`, `02-system-patterns`,
  `04-tech-context`, `07-constraints`, `08-governance`, `index`. Regenerated from
  `MASTER-SPEC.md` by `/scaffold-project`. Never hand-edit; edit MASTER-SPEC.md and
  re-derive.
- **Dev-authored** — `05-active-context`, `06-progress`, `09-known-issues`,
  `10-decisions-log`, `tech-debt`. Written while building; **preserved** across
  re-derive (seeded once if missing).
- **Mixed** — `03-code-patterns`. Spec-derived prose PLUS one preserved
  `## Machine-checkable rules` zone (between `<!-- mcrules:preserve:start/end -->`)
  that survives re-derive.

| Event | Files updated | By whom |
|---|---|---|
| `/onboard`, `/scaffold-project` | derive spec-derived files + `03` prose (preserve `03` rules zone); seed dev-authored files if missing | `scaffolding-memory-bank` |
| Work-item close | **none** — suggestions captured in `report.md` for later harvest | `implementer-agent` |
| Slice close | `05` cursor; `09-known-issues` + `10-decisions-log` (agent-judged harvest); `tech-debt` (auto-file sweep); `03` rules zone *only if* a discovered pattern is promoted to a rule | `closing-vertical-slice` |
| Sprint close | **none** — sprint retro is read-only aggregation | `writing-sprint-retrospective` |
| Continuous | `05` (focus changes); `06` (`add changelog entry` / by hand); `03` rules (`authoring-machine-checkable-rules`); `tech-debt` (`/defer`) | you / the named skill |
| Re-derive after MASTER-SPEC change | re-derive spec-derived files + `03` prose (rules zone preserved); dev-authored files untouched | `/scaffold-project` |

**Harvest routing (slice close):** caveats / gotchas / stack notes → `09-known-issues`;
decisions / advisory patterns → `10-decisions-log`; enforceable patterns → a
machine-checkable rule in `03` (via `authoring-machine-checkable-rules`). **Never**
append harvested prose into the spec-derived body of `03` / `04`.
```

- [ ] **Step 4: Rewrite the CLAUDE.md SSoT note**

In `scaffold-onboard/templates/claude-md/CLAUDE.md.tmpl`, replace the SSoT section (lines ~67–71):

```markdown
## SSoT discipline

- `MASTER-SPEC.md` is the source of truth. Derived files (memory-bank 00–04, 07, 08, index · docs/*) are regenerated by `/scaffold-project` and `/scaffold-docs`.
- Hand-edits to derived files will be overwritten. Edit MASTER-SPEC.md instead.
- `05-active-context.md` and `06-progress.md` are LIVE — owned by slice work, never auto-rewritten.
```

with:

```markdown
## SSoT discipline

- `MASTER-SPEC.md` is the source of truth for **spec-derived** files (memory-bank
  `00,01,02,04,07,08,index` · `docs/*`). They are regenerated by `/scaffold-project`
  and `/scaffold-docs`; hand-edits to them are overwritten — edit MASTER-SPEC.md instead.
- **Dev-authored** files (`05-active-context`, `06-progress`, `09-known-issues`,
  `10-decisions-log`, `tech-debt`) are written while building and **preserved** across
  re-derive. `03-code-patterns` is mixed: derived prose plus a preserved
  `## Machine-checkable rules` zone.
- For exactly when and by whom each file changes, see the single policy:
  `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**.
```

- [ ] **Step 5: Run test + full suite + commit**

Run: `bash scaffold-onboard/run-tests.sh tests/test-memory-bank.sh` → PASS
Run: `bash scaffold-onboard/run-tests.sh` → all PASS

```bash
git add scaffold-onboard/templates/memory-bank/WORKFLOW.md \
        scaffold-onboard/templates/claude-md/CLAUDE.md.tmpl \
        scaffold-onboard/tests/test-memory-bank.sh
git commit -m "feat(scaffold-onboard): single-point cadence policy in WORKFLOW.md + SSoT note rewrite (SS-1 W3, #45)"
```

---

## Task 4 (W4): Reroute slice-close harvest off derived files

**Files:**
- Modify: `scaffold-dev/lib/harvest.sh` (`sd_harvest_apply` — refuse/reroute derived-file targets)
- Modify: `scaffold-dev/skills/closing-vertical-slice/SKILL.md` §9.4 (kill phantoms; route to `09`/`10`; point to policy)
- Modify: `scaffold-dev/skills/closing-vertical-slice/references/memory-bank-harvest-example.md` (rework example off derived `02`)
- Test: `scaffold-dev/tests/test-harvest.sh`

**Design:** The policy says harvested prose never lands in spec-derived files (`00,01,02,04,07,08,index`) or `03`'s derived body. `sd_harvest_apply` currently writes to ANY `target_file`. Add a deterministic guard: if a target resolves to a spec-derived file, **reroute** to `09-known-issues.md` (the catch-all dev-authored bucket) and warn — never silently append into a derived file. Note `06-product-context.md` was always a phantom (no such file — `01` is product-context, `06` is progress); the categorize step must stop proposing it.

- [ ] **Step 1: Write failing tests for the derived-file guard**

Add to `scaffold-dev/tests/test-harvest.sh`:

```bash
# SS-1 W4 — harvest aimed at a spec-derived file is rerouted to 09-known-issues
# (never silently appended into the derived file).
test_apply_reroutes_derived_target() {
  echo "test_apply_reroutes_derived_target:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  mkdir -p "$TMP_AI_WORKSPACE/.claude/memory-bank"
  echo "# Code Patterns" > "$TMP_AI_WORKSPACE/.claude/memory-bank/02-system-patterns.md"
  local items='[{"source":"report","work_item":"1.01","target_file":"02-system-patterns.md","suggestion":"watch the startup race"}]'
  sd_harvest_apply "$items" "VS-3.2.1" 2>/dev/null
  # The derived file is untouched; the note landed in 09-known-issues.md instead.
  assert_file_not_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/02-system-patterns.md" "startup race"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/09-known-issues.md" "startup race"
}

# 09 / 10 / 05 / 06 / tech-debt remain valid (dev-authored) targets.
test_apply_allows_dev_authored_target() {
  echo "test_apply_allows_dev_authored_target:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  mkdir -p "$TMP_AI_WORKSPACE/.claude/memory-bank"
  local items='[{"source":"handoff","handoff_file":"vs-3.2.1-x.md","target_file":"10-decisions-log.md","item":"chose file-lock for the registry"}]'
  sd_harvest_apply "$items" "VS-3.2.1"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/10-decisions-log.md" "chose file-lock for the registry"
}
```

Confirm `assert_file_not_contains` exists in `scaffold-dev/tests/_helpers.sh`; if not, add it (mirror the scaffold-onboard helper). Add both test names to the invocation list before `sd_test_summary`.

> Existing test `test_apply_writes_trailer` targets `04-architecture.md` (NOT a real spec-derived file in this taxonomy — there is no `04-architecture`; the real `04` is `04-tech-context`). The guard keys off the exact derived basenames, so `04-architecture.md` is treated as a non-derived custom target and the existing test stays green. Leave it unchanged.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scaffold-dev/run-tests.sh tests/test-harvest.sh`
Expected: FAIL — `test_apply_reroutes_derived_target` fails (current code appends straight into `02-system-patterns.md`).

- [ ] **Step 3: Add the derived-file guard to `sd_harvest_apply`**

In `scaffold-dev/lib/harvest.sh`, add a helper near the top (after the `source` block):

```bash
# Spec-derived memory-bank basenames — harvest must NEVER append prose into these
# (SS-1 W4 / #45). Per the cadence policy (memory-bank/WORKFLOW.md), harvested prose
# routes to dev-authored files. 03-code-patterns is mixed: its derived body is off
# limits to raw harvest; enforceable patterns go through authoring-machine-checkable-rules.
_SD_HARVEST_DERIVED_FILES="00-project-brief.md 01-product-context.md 02-system-patterns.md 03-code-patterns.md 04-tech-context.md 07-constraints.md 08-governance.md index.md"

_sd_harvest_is_derived() {
  local f="$1" d
  for d in $_SD_HARVEST_DERIVED_FILES; do
    [[ "$f" == "$d" ]] && return 0
  done
  return 1
}
```

Then in the `sd_harvest_apply` loop, immediately after `target` is read and the empty-target guard, insert the reroute:

```bash
    if [[ -z "$target" ]]; then
      sd_log_warn "sd_harvest_apply: skipping item with no target_file: $text"
      continue
    fi

    # SS-1 W4: never append harvested prose into a spec-derived file — reroute to
    # the dev-authored catch-all (09-known-issues.md) and warn. Enforceable patterns
    # belong in 03's rules zone via authoring-machine-checkable-rules, not here.
    if _sd_harvest_is_derived "$target"; then
      sd_log_warn "sd_harvest_apply: '$target' is spec-derived — rerouting to 09-known-issues.md (cadence policy: memory-bank/WORKFLOW.md)"
      target="09-known-issues.md"
    fi
```

(The existing `local file="$mb/$target"` line below now uses the rerouted target.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scaffold-dev/run-tests.sh tests/test-harvest.sh`
Expected: PASS — reroute test green; dev-authored test green; all 12 prior tests still green.

- [ ] **Step 5: Fix the harvest target list in the SKILL + reference example**

In `scaffold-dev/skills/closing-vertical-slice/SKILL.md` §9.4 (line ~314), replace:

```markdown
For each candidate, decide which memory-bank file it belongs in (per scaffold-onboard's 11-file taxonomy): typically `03-code-patterns.md` (patterns + R2 rules), `04-tech-context.md` (stack-specific notes), `09-known-issues.md` (caveats + workarounds), `10-decisions-log.md` (ADR-worthy notes), or `06-product-context.md` (product-shape notes). Surface the proposed target alongside the candidate at step 5.
```

with:

```markdown
For each candidate, decide which **dev-authored** memory-bank file it belongs in, per
the cadence policy (`memory-bank/WORKFLOW.md` → **Memory-bank update cadence**, harvest
routing): caveats / gotchas / stack notes → `09-known-issues.md`; decisions / advisory
patterns → `10-decisions-log.md`; an enforceable pattern → NOT a raw harvest append —
route the user to `Skill(scaffold-onboard:authoring-machine-checkable-rules)` so it
lands in `03`'s preserved rules zone. Spec-derived files (`00,01,02,04,07,08,index`)
and `03`'s derived prose are **never** harvest targets; `sd_harvest_apply` reroutes any
such target to `09-known-issues.md` and warns. (There is no `06-product-context.md`
file — `06` is `06-progress`; `01` is product-context.) Surface the proposed target
alongside the candidate at step 5.
```

In `scaffold-dev/skills/closing-vertical-slice/references/memory-bank-harvest-example.md`, the worked example currently routes accepted items into `02-system-patterns.md` (a spec-derived file — now forbidden). Rework the example so the API-auth pattern and chatbot-intent items route to `09-known-issues.md` (stack/behavior notes) or are promoted to `03` rules via authoring-machine-checkable-rules, and the decision-flavored item routes to `10-decisions-log.md`. Update:
- Step 2 categorize table (lines ~38–47): change `02-system-patterns.md` targets to `09-known-issues.md`; keep the `03-code-patterns.md mcrule` row but note it goes through authoring-machine-checkable-rules.
- Step 5 append example (lines ~88–107): change the append destination from `.claude/memory-bank/02-system-patterns.md` to `.claude/memory-bank/09-known-issues.md`.
- Step 6 retrospective table (lines ~122–129): update the Target column accordingly.
- Add one line near the top pointing to the cadence policy for routing rules.

- [ ] **Step 6: Run full scaffold-dev suite + commit**

Run: `bash scaffold-dev/run-tests.sh`
Expected: all PASS — `test-harvest.sh` + any closing-vertical-slice eval-driven tests.

```bash
git add scaffold-dev/lib/harvest.sh \
        scaffold-dev/skills/closing-vertical-slice/SKILL.md \
        scaffold-dev/skills/closing-vertical-slice/references/memory-bank-harvest-example.md \
        scaffold-dev/tests/test-harvest.sh scaffold-dev/tests/_helpers.sh
git commit -m "feat(scaffold-dev): reroute slice-close harvest off spec-derived files (SS-1 W4, #45)"
```

---

## Task 5 (W5): De-contamination sweep — every cadence mention points to the policy

**Files (each gets its cadence restatement replaced with a pointer):**
- `scaffold-onboard/templates/memory-bank/05-active-context.md.tmpl` (header)
- `scaffold-onboard/templates/memory-bank/06-progress.md.tmpl` (header)
- `scaffold-onboard/templates/memory-bank/tech-debt.md.tmpl` (header)
- `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md` (§4 bucket-table prose — point to policy for *when*)
- `scaffold-onboard/skills/authoring-machine-checkable-rules/SKILL.md` (§8 — add policy pointer)
- `scaffold-dev/skills/executing-work-item/SKILL.md` (§4/§6 — "no memory-bank writes" → point to policy)
- `scaffold-dev/skills/deferring-work-item/SKILL.md` (§5 — tech-debt append → point to policy)
- `scaffold-dev/skills/writing-sprint-retrospective/SKILL.md` (§10 + Overview — sprint write-nothing → point to policy)
- `scaffold-dev/skills/closing-vertical-slice/SKILL.md` (§9 intro — add policy pointer; targets already fixed in W4)

**Rule:** Skills KEEP their operational mechanics (how to harvest, how to append a `[TD]` line). They must STOP independently asserting the cadence (which file at which event). Each restatement is replaced/augmented with the pointer phrase: `` See the canonical cadence policy: `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**. ``

- [ ] **Step 1: Add the pointer to the three live-file template headers**

`05-active-context.md.tmpl` — append to the blockquote header (after line 4):

```markdown
> Update cadence: see `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**.
```

`06-progress.md.tmpl` — append the same pointer line to its header blockquote.

`tech-debt.md.tmpl` — the header currently says "Filed by scaffold-dev's `/defer` command or the round-close auto-file sweep (#33)." Append:

```markdown
> Update cadence: see `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**.
```

- [ ] **Step 2: Point scaffold-onboard skills to the policy**

`scaffolding-memory-bank/SKILL.md` §4: after the bucket table, add one line:

```markdown
> The bucket table above describes derive *behavior*. For when each file is updated
> across the whole lifecycle (and by whom), the single source is
> `memory-bank/WORKFLOW.md` → **Memory-bank update cadence** — do not restate it here.
```

`authoring-machine-checkable-rules/SKILL.md` §8: add at the end of the section:

```markdown
> Cadence note: rules are added continuously by this skill; the full update cadence
> lives in `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**.
```

- [ ] **Step 3: Point scaffold-dev skills to the policy**

`executing-work-item/SKILL.md` §4 (the "No memory-bank writes…" line, ~144): append:

```markdown
(Cadence reference: `memory-bank/WORKFLOW.md` → **Memory-bank update cadence** — work-item close writes nothing to the memory bank.)
```

`deferring-work-item/SKILL.md` §5: after the append instruction, add:

```markdown
> Cadence: `tech-debt.md` is dev-authored; see `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**.
```

`writing-sprint-retrospective/SKILL.md` Overview + §10 anti-pattern: where it says sprint-level promotion is "deferred from v0.1 / an open question", replace that framing with the policy decision:

```markdown
Sprint close writes **nothing** to the memory bank — the per-slice harvest is the
single promotion event (see `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**).
The sprint retro AGGREGATES counts; it does NOT re-promote items.
```

`closing-vertical-slice/SKILL.md` §9 intro (line ~288): add:

```markdown
> Harvest is the slice-close memory-bank write event per the cadence policy
> (`memory-bank/WORKFLOW.md` → **Memory-bank update cadence**). This section is the
> *mechanics*; the policy owns *which files at which event*.
```

- [ ] **Step 4: Manual scan for any missed restatement**

Run a broad grep and eyeball each hit — anything that asserts "X file updates at Y event" outside `WORKFLOW.md` must become a pointer:

```bash
grep -rn -iE 'never hand-edit|will be overwritten|update (as|after)|append after every commit|live file|seeded (once|if missing)|re-run /scaffold-project after' \
  scaffold-onboard/skills scaffold-onboard/templates scaffold-dev/skills 2>/dev/null
```

For each genuine cadence restatement found, replace with the pointer phrase. (Operational mechanics that don't state cadence are left alone.)

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/templates/memory-bank/05-active-context.md.tmpl \
        scaffold-onboard/templates/memory-bank/06-progress.md.tmpl \
        scaffold-onboard/templates/memory-bank/tech-debt.md.tmpl \
        scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md \
        scaffold-onboard/skills/authoring-machine-checkable-rules/SKILL.md \
        scaffold-dev/skills/executing-work-item/SKILL.md \
        scaffold-dev/skills/deferring-work-item/SKILL.md \
        scaffold-dev/skills/writing-sprint-retrospective/SKILL.md \
        scaffold-dev/skills/closing-vertical-slice/SKILL.md
git commit -m "refactor(scaffold): point all cadence mentions to the single WORKFLOW.md policy (SS-1 W5, #45)"
```

---

## Task 6 (W6): Grep-guard single-source test + cross-cutting acceptance

**Files:**
- Create: `scaffold-onboard/tests/test-cadence-single-source.sh`
- Test: confirms exactly one canonical marker + that sweep targets carry the pointer

**Design:** Single-source is a *mechanical* fact (marker uniqueness) → deterministic guard is appropriate (per `feedback_agent_review_over_deterministic_gates`, mechanical facts keep deterministic checks). The guard asserts the `<!-- cadence-policy:canonical -->` marker appears exactly once across both plugins, and that the rendered `WORKFLOW.md` is where it lives.

- [ ] **Step 1: Write the grep-guard test**

Create `scaffold-onboard/tests/test-cadence-single-source.sh`:

```bash
#!/usr/bin/env bash
# test-cadence-single-source.sh — SS-1 W6 grep-guard: the memory-bank update cadence
# is stated in exactly ONE place (WORKFLOW.md, marked canonical). Every other skill
# points to it rather than restating it.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"

# Repo root = two levels up from scaffold-onboard/tests
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

test_canonical_marker_unique() {
  echo "test_canonical_marker_unique:"
  local n
  n="$(grep -rl 'cadence-policy:canonical' \
        "$REPO_ROOT/scaffold-onboard" "$REPO_ROOT/scaffold-dev" 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$n" == "1" ]]; then
    PASS=$((PASS+1)); echo "  ✓ exactly one canonical cadence marker"
  else
    FAIL=$((FAIL+1)); echo "  ✗ expected 1 canonical marker, found $n"
    grep -rl 'cadence-policy:canonical' "$REPO_ROOT/scaffold-onboard" "$REPO_ROOT/scaffold-dev"
  fi
}

test_canonical_marker_in_workflow() {
  echo "test_canonical_marker_in_workflow:"
  if grep -q 'cadence-policy:canonical' "$REPO_ROOT/scaffold-onboard/templates/memory-bank/WORKFLOW.md"; then
    PASS=$((PASS+1)); echo "  ✓ canonical marker lives in WORKFLOW.md template"
  else
    FAIL=$((FAIL+1)); echo "  ✗ canonical marker not in WORKFLOW.md template"
  fi
}

test_sweep_targets_point_to_policy() {
  echo "test_sweep_targets_point_to_policy:"
  local missing=0 f
  for f in \
    "$REPO_ROOT/scaffold-onboard/templates/memory-bank/05-active-context.md.tmpl" \
    "$REPO_ROOT/scaffold-onboard/templates/memory-bank/06-progress.md.tmpl" \
    "$REPO_ROOT/scaffold-onboard/templates/memory-bank/tech-debt.md.tmpl" \
    "$REPO_ROOT/scaffold-dev/skills/executing-work-item/SKILL.md" \
    "$REPO_ROOT/scaffold-dev/skills/deferring-work-item/SKILL.md" \
    "$REPO_ROOT/scaffold-dev/skills/writing-sprint-retrospective/SKILL.md"; do
    if ! grep -q 'Memory-bank update cadence' "$f"; then
      echo "  ✗ no policy pointer in $f"; missing=$((missing+1))
    fi
  done
  if [[ "$missing" == "0" ]]; then PASS=$((PASS+1)); echo "  ✓ all sweep targets point to the policy";
  else FAIL=$((FAIL+1)); fi
}

test_canonical_marker_unique
test_canonical_marker_in_workflow
test_sweep_targets_point_to_policy
report_results
```

Confirm `scaffold-onboard/tests/_helpers.sh` defines `PASS`/`FAIL`/`report_results` (it does — used by test-memory-bank.sh).

- [ ] **Step 2: Run the grep-guard**

Run: `bash scaffold-onboard/run-tests.sh tests/test-cadence-single-source.sh`
Expected: PASS (after W3 + W5 done). If `test_canonical_marker_unique` fails with >1, a restatement still carries the marker — remove the stray marker (the pointer phrase is fine; only the `cadence-policy:canonical` marker must be unique).

- [ ] **Step 3: Run BOTH full suites — cross-cutting green gate**

```bash
bash scaffold-onboard/run-tests.sh
bash scaffold-dev/run-tests.sh
bash tests/test-codex-dual-publish.sh
```

Expected: all green. This is the acceptance gate for SS-1 §6: new files seeded+preserved (W1), `03` rules survive re-derive (W2), harvest reroutes off derived files (W4), single-source enforced (W6), existing suites stay green.

- [ ] **Step 4: Commit**

```bash
git add scaffold-onboard/tests/test-cadence-single-source.sh
git commit -m "test(scaffold-onboard): grep-guard enforces single-source cadence policy (SS-1 W6, #45)"
```

---

## Task 7 (W7): One-time migration — relocate provenance-trailed content out of `03`/`04`

**Files:**
- Modify: `scaffold-onboard/lib/memory-bank.sh` (`_sf_mb_migrate_harvested` + call it at the top of `sf_memory_bank_derive`)
- Test: `scaffold-onboard/tests/test-memory-bank.sh`

**Design:** Existing projects (e.g. the PulseTrader test project) already have harvest content appended into derived `03`/`04` with provenance trailers `<!-- Added from VS… -->`. Before regenerating those files (which would clobber the content), detect provenance-trailed entries in `03`/`04`, **relocate** them to `09-known-issues.md` (catch-all), print a summary, and never silent-drop. Idempotent: once relocated, the derived file no longer matches, so a second run is a no-op. The relocation must run BEFORE the derive loop overwrites `03`/`04`. Migration relocates from `03` **outside** its preserve zone only (the preserve zone is handled by W2; user mcrule blocks are not "harvested prose").

- [ ] **Step 1: Write failing test for migration**

Add to `scaffold-onboard/tests/test-memory-bank.sh`:

```bash
# SS-1 W7 — provenance-trailed harvest content in a derived file is relocated to
# 09-known-issues.md before re-derive, never silently dropped.
test_migration_relocates_harvested_content() {
  echo "test_migration_relocates_harvested_content:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  # Simulate an old project: harvest content was appended into derived 04.
  {
    echo ""
    echo "- legacy harvested note: prefer atomic writes for the registry"
    echo "<!-- Added from VS-1.1.1 retrospective, 2026-05-01; source: report -->"
  } >> ".claude/memory-bank/04-tech-context.md"
  # Re-derive: migration must move it to 09 before 04 is regenerated.
  sf_memory_bank_derive
  assert_file_contains "./.claude/memory-bank/09-known-issues.md" "prefer atomic writes for the registry"
  assert_file_not_contains "./.claude/memory-bank/04-tech-context.md" "prefer atomic writes for the registry"
}

# Idempotent — a second re-derive does not duplicate.
test_migration_idempotent() {
  echo "test_migration_idempotent:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  {
    echo ""
    echo "- legacy note: one-shot relocate me"
    echo "<!-- Added from VS-2.1.1 retrospective, 2026-05-02; source: handoff -->"
  } >> ".claude/memory-bank/03-code-patterns.md"
  sf_memory_bank_derive
  sf_memory_bank_derive
  local count
  count="$(grep -c "one-shot relocate me" "./.claude/memory-bank/09-known-issues.md")"
  if [[ "$count" == "1" ]]; then PASS=$((PASS+1)); echo "  ✓ relocated exactly once";
  else FAIL=$((FAIL+1)); echo "  ✗ expected 1 relocation, found $count"; fi
}
```

Add both names to the invocation list.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scaffold-onboard/run-tests.sh tests/test-memory-bank.sh`
Expected: FAIL — no migration step yet; the note in `04` is clobbered by re-derive and never appears in `09`.

- [ ] **Step 3: Implement the migration helper + wire it in**

In `scaffold-onboard/lib/memory-bank.sh`, add this helper (after the preserve-zone helpers from W2):

```bash
# One-time migration (SS-1 W7): relocate provenance-trailed harvest content
# (a "- <text>" line immediately followed by a "<!-- Added from VS… -->" trailer)
# out of derived files 03/04 into 09-known-issues.md, BEFORE those files are
# re-rendered. Never silent-drop: every relocated entry is appended to 09 (with its
# trailer) and a summary is logged. Idempotent: relocated entries no longer match.
# For 03, only content OUTSIDE the mcrules preserve zone is migrated.
_sf_mb_migrate_harvested() {
  local mb=".claude/memory-bank"
  local known="$mb/09-known-issues.md"
  local moved=0 src
  for src in "$mb/03-code-patterns.md" "$mb/04-tech-context.md"; do
    [[ -f "$src" ]] || continue
    local relocated kept
    relocated="$(mktemp)"; kept="$(mktemp)"
    # awk: a bullet line followed on the NEXT line by an "Added from VS" trailer is a
    # harvested pair → emit to relocated; everything else → kept. Skip lines inside
    # the mcrules preserve zone (never migrate user rule blocks).
    awk -v rel="$relocated" -v kp="$kept" '
      /<!-- mcrules:preserve:start -->/ { inzone=1 }
      {
        if (inzone) { print > kp;
          if ($0 ~ /<!-- mcrules:preserve:end -->/) inzone=0;
          next }
        line[NR]=$0
      }
      END { }
    ' "$src" 2>/dev/null
    # Simpler two-pass with getline is awkward in BSD awk; use a line-buffer approach:
    : > "$relocated"; : > "$kept"
    local prev="" have_prev=0
    while IFS= read -r cur || [[ -n "$cur" ]]; do
      if [[ "$cur" == *"<!-- Added from VS"* && "$have_prev" -eq 1 && "$prev" == -* ]]; then
        printf '%s\n%s\n' "$prev" "$cur" >> "$relocated"
        have_prev=0; prev=""
        continue
      fi
      if [[ "$have_prev" -eq 1 ]]; then printf '%s\n' "$prev" >> "$kept"; fi
      prev="$cur"; have_prev=1
    done < "$src"
    [[ "$have_prev" -eq 1 ]] && printf '%s\n' "$prev" >> "$kept"

    if [[ -s "$relocated" ]]; then
      [[ -f "$known" ]] || printf '# Known Issues\n' > "$known"
      {
        echo ""
        echo "## Migrated from $(basename "$src") (SS-1)"
        cat "$relocated"
      } >> "$known"
      mv "$kept" "$src"
      local c; c="$(grep -c '<!-- Added from VS' "$relocated")"
      moved=$((moved + c))
      sf_log_warn "migrated $c harvested entr$([[ $c -eq 1 ]] && echo y || echo ies) from $(basename "$src") → 09-known-issues.md (SS-1 W7)"
    fi
    rm -f "$relocated" "$kept"
  done
  [[ "$moved" -gt 0 ]] && sf_log_info "SS-1 migration: relocated $moved harvested entries into 09-known-issues.md"
  return 0
}
```

> Note: the awk first-pass above is vestigial scaffolding — the working logic is the bash `while read` line-buffer loop (BSD-awk-safe). Drop the awk block entirely; keep only the `: > "$relocated"` onward. (Cleaned up in Step 5.)

Wire it into `sf_memory_bank_derive` — call it AFTER `mkdir -p .claude/memory-bank` and BEFORE the derived-file loop, but only when `09-known-issues.md` can exist (it's seeded later in the same run, so the helper creates it if needed):

```bash
  mkdir -p .claude/memory-bank

  # SS-1 W7: one-time relocate of provenance-trailed harvest content out of derived
  # 03/04 before they are regenerated. No-op on fresh projects.
  _sf_mb_migrate_harvested
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scaffold-onboard/run-tests.sh tests/test-memory-bank.sh`
Expected: PASS — content relocated to `09`, removed from `04`/`03`, idempotent.

- [ ] **Step 5: Simplify the helper (remove vestigial awk) + re-run**

Remove the dead awk first-pass block flagged in Step 3 so the helper contains only the bash line-buffer loop. Re-run:

Run: `bash scaffold-onboard/run-tests.sh tests/test-memory-bank.sh` → PASS (behavior unchanged).

- [ ] **Step 6: Run full scaffold-onboard suite + commit**

Run: `bash scaffold-onboard/run-tests.sh` → all PASS

```bash
git add scaffold-onboard/lib/memory-bank.sh scaffold-onboard/tests/test-memory-bank.sh
git commit -m "feat(scaffold-onboard): one-time migration of harvested content out of derived 03/04 (SS-1 W7, SP-5, #45)"
```

---

## Task 8: Release — version bumps, README, tags

**Files:**
- Modify: `scaffold-onboard/.claude-plugin/plugin.json` + `scaffold-onboard/.codex-plugin/plugin.json` (parity)
- Modify: `scaffold-dev/.claude-plugin/plugin.json` + `scaffold-dev/.codex-plugin/plugin.json` (parity)
- Modify: `scaffold-onboard/CHANGELOG.md`, `scaffold-dev/CHANGELOG.md`
- Modify: `README.md` (root version table)

- [ ] **Step 1: Read current versions + bump both plugins (Claude + Codex parity)**

```bash
grep -H '"version"' scaffold-onboard/.claude-plugin/plugin.json scaffold-onboard/.codex-plugin/plugin.json \
  scaffold-dev/.claude-plugin/plugin.json scaffold-dev/.codex-plugin/plugin.json
```

Bump scaffold-onboard (memory-bank derive changes are a minor feature) and scaffold-dev (harvest reroute) per the program's release mechanics. Set the SAME version string in each plugin's `.claude-plugin` AND `.codex-plugin` `plugin.json` (parity is enforced by `tests/test-codex-dual-publish.sh`). Decide the exact bump from the current values (e.g. scaffold-onboard 0.3.8 → 0.4.0; scaffold-dev 0.2.0 → 0.3.0 — confirm against the grep output).

- [ ] **Step 2: Update CHANGELOGs + README version table**

Add a dated release section to each plugin's `CHANGELOG.md` summarizing SS-1 (new `09`/`10` files, `03` preserved rules zone, single-point cadence policy, harvest reroute, migration). Update the version cells in root `README.md`.

- [ ] **Step 3: Dual-publish parity gate + both suites**

```bash
bash tests/test-codex-dual-publish.sh
bash scaffold-onboard/run-tests.sh
bash scaffold-dev/run-tests.sh
```
Expected: all green.

- [ ] **Step 4: Commit, open PR, bot-review babysitting**

```bash
git add -A
git commit -m "release: scaffold-onboard v<X> + scaffold-dev v<Y> — SS-1 memory-bank ownership & cadence (closes #45)"
```

Open a PR to `main`. Then run the proven bot-review loop (per the handoff §4): the user triggers the Codex GitHub app; fetch inline comments via `gh api repos/<o>/<r>/pulls/<n>/comments`; **verify each finding before applying** (`superpowers:receiving-code-review`); a Codex 👍 reaction means clean. Consider a proactive `superpowers:requesting-code-review` self-audit before requesting bot review.

- [ ] **Step 5: After squash-merge — tag releases**

```bash
git fetch && git checkout main && git reset --hard origin/main
git tag scaffold-onboard-v<X>
git tag scaffold-dev-v<Y>
git push --tags
```

Then close #45 (and note #48 C/D/E partial progress) and update the program ledger (`docs/agent-driven-program/SPEC-agent-driven-program.md` §6) marking SS-1 done.

---

## Self-Review (run after writing — completed)

**1. Spec coverage** (SS-1 §4 work items → tasks):
- W1 new files + templates + live-seed + index + load-tier → **Task 1** ✓
- W2 `03` rules-zone preservation (both paths) → **Task 2** ✓
- W3 cadence policy + SSoT note rewrite → **Task 3** ✓
- W4 harvest target-set rewrite → **Task 4** ✓
- W5 de-contamination sweep (both plugins) → **Task 5** ✓
- W6 tests (incl. grep-guard) → embedded per-task (TDD) + **Task 6** (single-source guard + cross-cutting gate) ✓
- W7 migration → **Task 7** ✓
- Release mechanics (program §9) → **Task 8** ✓

SS-1 §5 sweep-target table: every row mapped in Task 5 (WORKFLOW.md = Task 3; 05/06/tech-debt headers, executing-work-item, deferring-work-item, authoring-machine-checkable-rules, writing-sprint-retrospective, scaffolding-memory-bank, CLAUDE.md = Task 3, closing-vertical-slice §9 = Tasks 4+5). ✓

SS-1 §6 acceptance: new files seeded+preserved (T1), `03` rules survive (T2), harvest refuses/reroutes derived (T4), grep-guard single-source (T6), suites stay green (T6 §3). ✓

SS-1 §7 settle-points: SP-1 policy in WORKFLOW.md (T3) · SP-2 two buckets 09/10 (T1) · SP-3 sprint write-nothing (T5 writing-sprint-retro) · SP-4 09=Tier0/10=on-demand (T1 index + CLAUDE preload) · SP-5 migration never-silent-drop (T7). ✓

**2. Placeholder scan:** Version numbers in Task 8 are intentionally `<X>`/`<Y>` (resolved from a live grep — the actual current versions aren't knowable until execution). Every code/template step has concrete content. No TODO/TBD left in plan logic.

**3. Type/name consistency:** Marker strings (`mcrules:preserve:start/end`, `cadence-policy:canonical`), helper names (`_sf_mb_extract_preserve_zone`, `_sf_mb_reinject_preserve_zone`, `_sf_mb_migrate_harvested`, `_sd_harvest_is_derived`), pointer phrase, and ownership-class file lists are identical across all tasks. ✓
