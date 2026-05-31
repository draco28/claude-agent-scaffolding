---
name: implementation-checking
description: 'Per-work-item verification gate — runs `auto:` AC lines (halt-on-first-fail), cross-checks `report.md` outcomes, checks machine-checkable rules from `03-code-patterns.md`; surfaces source-tagged errors (`[AC]`, `[report cross-check]`, `[rule]`) + menu on fail; reports green on all-pass. Use this when the user wants to verify work item N.NN, check round 1, asks "is this work item done", or says "verify the implementation". Read-only: never commits, merges, or auto-fixes.'
---

# implementation-checking

You are scaffold-dev v0.1's per-work-item verification gate. The orchestrator (`planning-vertical-slice`) hands you a work item after the implementer-agent subagent returns `mode: complete`; you decide whether that work item is ready for commit + merge, or whether it bounces back to the user via the §12.2 failure-response menu.

Three checks, in order:

1. **AC verification** — parse the `auto:` lines from the work-item spec, run each in the worktree, halt on the first failure.
2. **Report cross-check** — read `report.md`, confirm its AC-outcome claims match the observed reality.
3. **Project rule check** — if scaffold-onboard's `03-code-patterns.md` has mcrule blocks, consult `sf_rules_*` and run the rules against the work item's modified files; if rules are absent, surface a user-visible advisory and skip.

On any fail, surface a source-tagged error report and the matching §12.2 menu row. On all-pass, report green and hand control back. Never commit, never merge, never edit `report.md` or `handoff.md`, never auto-fix violations — those decisions belong to the user.

Bash helpers in `lib/verify.sh`, `lib/rules.sh`, and `lib/manifest.sh` do the I/O. Judgment — which menu row applies, how to phrase the source-tagged error, whether the rules-absent advisory belongs above or below the green summary — happens here in conversation.

This skill is the per-work-item gate. It does NOT plan slices (that's `planning-vertical-slice`), does NOT execute work-item code (that's the `scaffold-dev:implementer-agent` subagent body), and does NOT close slices (that's `closing-vertical-slice`). It is invoked from `planning-vertical-slice` §8.5 after each subagent complete-mode return, or directly by the user via a trigger phrase.

---

## 1. Overview

When invoked, you:

1. Discover the workspace-init pairing manifest; refuse fail-fast if absent.
2. Resolve the work-item id from the user message (or the active-context cursor when ambiguous).
3. Locate the work-item directory under `<ai-workspace>/docs/specs/sprint-<sprint_id>/VS-N.M.K-<kebab>/work-N.NN-<kebab>/` and the matching worktree under `${worktrees_dir}/sprint-<sprint_id>/work-N.NN-<kebab>`.
4. Read `spec.md`; extract the `auto:` AC list per SPEC §14.1 grammar.
5. Probe `<ai-workspace>/.claude/memory-bank/03-code-patterns.md` for `<!-- mcrule:start ... -->` blocks (rules-presence binary).
6. Execute each `auto:` step sequentially in the worktree; **halt on the first failure**.
7. Read `report.md`; cross-check its AC-outcome claims against observed reality.
8. If mcrule blocks are present, parse rules via `sf_rules_parse`, filter via `sf_rules_filter`, and apply via `sd_rules_apply` against the worktree's modified files.
9. Branch on outcome:
   - **All-pass + rules present** → green summary + ready-for-commit handoff.
   - **All-pass + rules absent** → green summary + one-line advisory naming the rules-absent condition.
   - **AC fail** → halt; `[AC]`-tagged error + §12.2 row 1 menu (3 options).
   - **Report cross-check mismatch** (ACs themselves not failing) → `[report cross-check]`-tagged error + §12.2 row 2 menu (3 options).
   - **Rule fail** → ACs reported as passed first, then `[rule]`-tagged error + §12.2 row 3 menu (3 options).

Phase 1 RED→GREEN: this body's behavior is contracted by `scaffold-dev/evals/implementation-checking.md` — the four scenarios there are the binding spec.

---

## 2. When to use

**Trigger phrases (description-match):**

- `verify work item N.NN`, `verify work item 2.04`
- `check round 1`, `check round K`
- `is this work item done`, `did the work item pass`
- `verify the implementation`, `verify the work item`

**Invoked programmatically from `planning-vertical-slice` §8.5** after each implementer-agent subagent returns `mode: complete`. In that path the orchestrator passes `work_item_id=<N.NN>` and you skip the cursor-lookup branch in §3.2.

**Do NOT auto-invoke when:**

- The work item directory does not exist. Surface the missing-spec error in §3.4 and stop.
- The worktree does not exist. Surface the missing-worktree error in §3.5 and stop.
- The implementer-agent subagent has NOT yet returned `mode: complete`. Verification gates a complete-mode return; if the subagent is still in gaps-surfaced mode, route back to `planning-vertical-slice` §8.4 for the multi-call clarification loop.
- The user wants to *plan* a slice or *execute* a work item — those are different skills.

---

## 3. Pre-flight

Before any verification step, validate prerequisites in this order. Any failure surfaces the error string and stops.

### 3.1 Manifest discovery

Call `sd_manifest_require` (lib/manifest.sh). If absent, surface this verbatim refusal and stop:

> scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first.

The literal `/init-workspace` and `/pair-workspace` slash-command tokens are load-bearing (mirrors `planning-vertical-slice` §3.1). Do NOT read the spec, do NOT run any `auto:` commands, do NOT probe rules.

All scaffold-dev lib calls go through the `sd` dispatcher (`scaffold-dev/bin/sd`, on `$PATH` because Claude Code adds each plugin's `bin/` automatically; the dispatcher's bash shebang forces a bash runtime under it regardless of the calling shell — required because Claude Code's Bash tool runs zsh by default on macOS):

```bash
if ! sd manifest_require 2>/dev/null; then
  printf '%s\n' "scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."
  exit 0
fi
```

Never read manifest fields via raw inline `jq`. All manifest reads route through `sd_manifest_get` / `sd_manifest_resolve`.

### 3.2 Resolve the work-item id

Resolution priority:

1. **Explicit id** in the user message (e.g., `verify work item 3.2.01`) — match the `N.NN` or `N.M.NN` token; use as-is.
2. **Orchestrator handoff** — when invoked from `planning-vertical-slice` §8.5, the work item id is passed as a parameter; use that.
3. **Active-context cursor** — read `<ai-workspace>/.claude/memory-bank/05-active-context.md` for the in-flight work item; use that when the message is ambiguous (e.g., `is this work item done`, `verify the implementation`).
4. **Round-level** — when the user says `check round K`, enumerate the round's work items from the slice README and iterate; for the v0.1 happy path with one item per round, this collapses to the single-item case.

Whichever branch resolves the id MUST assign it to `work_id` before continuing.

If none of the above produces an id, ask: *"Which work item? (e.g., `1.01`)"* and wait.

### 3.3 Read manifest fields

```bash
ai_workspace="$(sd manifest_get '.ai_workspace.root')"
canonical="$(sd manifest_get '.canonical.root')"
worktrees_dir="$(sd manifest_resolve "$ai_workspace" "$(sd manifest_get '.during_dev.worktrees_dir')")"
sprint_dir_template="$(sd manifest_get '.during_dev.sprint_dir_template')"
```

### 3.4 Locate the work-item directory

The active slice is recorded in the cursor; its `sprint_id` is **field-read** from the structured roadmap (#28 — never split out of the slice id). Kebabs were chosen at planning time and aren't known here, so locate the existing dir by glob rather than reconstructing it:

```bash
vs_id="$(sd state_active_slice)"                    # e.g. VS-1.1.1
sprint_id="$(sd roadmap_slice_sprint_id "$vs_id")"  # e.g. 1.1 (field-read)
: "${work_id:?work item id was not resolved by section 3.2}"  # e.g. 1.01

shopt -s nullglob
work_dir_matches=("${ai_workspace}/docs/specs/sprint-${sprint_id}/${vs_id}-"*/"work-${work_id}-"*)
shopt -u nullglob
if [[ "${#work_dir_matches[@]}" -ne 1 ]]; then
  printf 'Work item %s matched %s directories under %s/docs/specs/sprint-%s/%s-*/\n' \
    "$work_id" "${#work_dir_matches[@]}" "$ai_workspace" "$sprint_id" "$vs_id"
  exit 0
fi
work_dir="${work_dir_matches[0]}"
```

If `work_dir` is empty or its `spec.md` does not exist, surface:

> Work item `<work_id>` not found under `${ai_workspace}/docs/specs/sprint-${sprint_id}/${vs_id}-*/`. Has `planning-vertical-slice` authored this slice yet?

Then stop. Do NOT auto-create the directory; spec authoring is the orchestrator's lane.

### 3.5 Locate the worktree

Resolve:

```bash
shopt -s nullglob
worktree_matches=("${worktrees_dir}/sprint-${sprint_id}/work-${work_id}-"*)
shopt -u nullglob
if [[ "${#worktree_matches[@]}" -ne 1 ]]; then
  printf 'Worktree for %s matched %s paths under %s/sprint-%s/\n' \
    "$work_id" "${#worktree_matches[@]}" "$worktrees_dir" "$sprint_id"
  exit 0
fi
worktree="${worktree_matches[0]}"
```

If the worktree does not exist (i.e., `git worktree list` does not include the path), surface:

> Worktree for `<work_id>` not found at `<resolved-path>`. Has the orchestrator run §8.1 (`sd_worktree_add`) for this round?

Then stop. The worktree is the implementer's sandbox; verifying without it produces a false-green.

---

## 4. AC parsing (per SPEC §14.1 grammar)

Read `${work_dir}/spec.md` and locate the **Acceptance Criteria** section. The spec is authored from `templates/work-item-spec.md.tmpl` (8 sections per SPEC §9); section 6 is "Acceptance criteria (machine-checkable)".

For each AC line matching the `auto:` grammar:

```
- [ ] AC-1 auto: `<bash command>` → expected: <exit 0 | exit N | output contains <substring>>
```

(use a real number — `AC-1`, `AC-2`, … — not the literal `AC-N`, which the report cross-check would grep as a phantom id.)

Extract:

- **`command`** — the bash command **inside the backticks** after `auto:` (`sd_verify_auto_step` extracts it from the backticks; an un-backticked command is rejected as malformed). The literal U+2192 arrow `→` (NOT `->`) separates it from `expected:`.
- **`expectation`** — the predicate after `expected:`. Only three forms are supported by `sd_verify_auto_step`: `exit 0`, `exit N`, and `output contains <substring>` (substring **unquoted** — it is matched literally via `grep -F`, so wrapping quotes would be required in the output).

Build an ordered list of `(ac_label, command, expectation)` tuples. The `ac_label` is the line's `AC-N` ID (1-indexed) — these IDs also drive the report cross-check (§7), so every AC line must carry one.

Lines with `user:` prefix are manual demo steps, not auto ACs — they're verified at slice-close per `closing-vertical-slice` §14.2, NOT here. Skip them silently in this gate.

**Zero-AC degrade (issue #36).** If, after scanning §6, the `auto:` tuple list is
**empty**, do NOT proceed to a green summary. Emit a blocking advisory tagged `[AC]`:

> `[AC] No machine-runnable auto: ACs found in <spec path>. The gate cannot
> auto-verify this work item — manual verification is required before merge.`

Then surface a §12.2-style menu (≥3 options, matching the §9.3 / §9.5 fail-path
menus) so the user explicitly chooses — never silently report the work item ready:

1. Proceed with manual verification (operator vouches for the ACs out-of-band).
2. Re-author the spec with `auto:` lines, then re-run the gate from §4.
3. Abort and return the work item to the implementer.

A zero-AC spec is a spec-authoring defect, not a pass.

---

## 5. Rules-presence probe

Before any AC execution, probe `<ai-workspace>/.claude/memory-bank/03-code-patterns.md` for mcrule blocks (single Read or Grep call). Two binary outcomes:

- **Present:** at least one `<!-- mcrule:start type=<T> -->` block exists under `## Machine-checkable rules`. Set `rules_present=1`; defer rule application until §8.
- **Absent:** the file does not exist, OR the section is empty, OR no mcrule block matches. Set `rules_present=0`; the rules-absent advisory is queued for the green summary (§9.2).

Per SPEC §12.1 + Q2 settlement: rules-absent is NOT an error — it's the v0.1 fallback. The advisory in §9.2 ensures the user is not silently misled into thinking rule coverage existed.

Do NOT run `sf_rules_parse` or `sf_rules_filter` against an empty section — eval S4's assertion explicitly rejects spurious `sf_rules_*` evaluation calls beyond the absence-detection probe.

```bash
patterns_file="${ai_workspace}/.claude/memory-bank/03-code-patterns.md"
if [[ -f "$patterns_file" ]] && grep -q '<!-- mcrule:start ' "$patterns_file"; then
  rules_present=1
else
  rules_present=0
fi
```

---

## 6. AC verification loop (halt on first fail)

Iterate the `(ac_label, command, expectation)` tuples in declared order. For each, call:

```bash
sd verify_auto_step "$command" "$expectation" "$worktree"
```

`sd_verify_auto_step` (lib/verify.sh):
- Executes `command` in `$worktree` (uses `cd "$worktree" && eval "$command"` for shell commands; `git -C "$worktree" ...` for git ops per SPEC §6.5).
- Captures exit code + stdout + stderr.
- Evaluates `expectation` per §14.1: `exit 0` → exit-code check; `output contains "<pat>"` → substring match against stdout; numeric comparisons → arithmetic against captured output.
- Returns 0 on pass, non-zero on fail. Emits a structured result line on stderr: `STATUS=<pass|fail> EXIT=<n> OUTPUT_HEAD=<first 200 chars>`.

**Halt-on-first-fail is binding.** Eval S2 asserts that on AC-1 fail, AC-2 and AC-3 MUST NOT appear in the Bash tool-call log. Do NOT continue iterating "to gather more failures" — the user picks a §12.2 option, the implementer-agent re-runs, and verification re-starts from AC-1 on the next pass.

```bash
for tuple in "${ac_tuples[@]}"; do
  IFS='|' read -r label cmd expect <<<"$tuple"
  if ! sd_verify_auto_step "$cmd" "$expect" "$worktree" 2>verify.err; then
    failing_ac_label="$label"
    failing_cmd="$cmd"
    failing_output="$(cat verify.err)"
    break  # HALT — do not continue
  fi
  ac_results+=("${label}:pass")
done
```

When the loop completes without a break, all ACs passed; proceed to §7 report cross-check.

When the loop breaks, jump directly to §9.3 (`[AC]`-tagged error + §12.2 row 1 menu).

---

## 7. Report cross-check

Read `${work_dir}/report.md`. The implementer-agent authors this per the §10 report template (Status, Summary, Files changed, AC outcomes, Notes, Gaps).

Cross-check the **AC outcomes** section against your freshly-measured `ac_results`:

- For each AC line in the report, parse the claimed outcome (e.g., `AC-1: pass`, `AC-2: fail (test X timed out)`).
- Compare against your observed `ac_results`.
- **Match** → record `report_match=1`.
- **Mismatch** (any AC where claimed ≠ observed) → record `report_match=0`, capture the offending AC label + claimed vs observed.

Also cross-check the **Status** line: if the report says `complete` but any AC failed in §6, that's a mismatch (the implementer-agent should have returned `mode: gaps-surfaced` rather than authoring a `complete` report with a failing AC).

When this gate is reached, §6 already passed (all ACs green). So the only mismatch shape that can land here is: report claims an AC failed but the gate observes it passing, OR report's Status disagrees with the all-pass observation. Both are rare and indicate report-authoring drift, not implementation drift.

On mismatch with ACs themselves green: jump to §9.4 (`[report cross-check]`-tagged error + §12.2 row 2 menu).

On match: proceed to §8 rule application.

---

## 8. Rule application (when `rules_present=1`)

If `rules_present=0`, skip this section entirely; proceed to §9.2 green summary with the rules-absent advisory.

When rules are present:

### 8.1 Parse + filter

Use scaffold-onboard's `sf` dispatcher for this — `sf_rules_*` lives in scaffold-onboard per SPEC §16.2, not scaffold-dev. The `sf` dispatcher is also on `$PATH` (Claude Code adds every plugin's `bin/` automatically):

```bash
rules_json="$(sf rules_parse "$patterns_file")"
```

`sf rules_parse` returns a JSON array of rule objects (one per mcrule block). Filter by type for each of the four v0.2 rule families:

```bash
banned_imports_rules="$(sf rules_filter "$rules_json" 'banned_imports')"
coverage_floor_rules="$(sf rules_filter "$rules_json" 'coverage_floor')"
style_invariants_rules="$(sf rules_filter "$rules_json" 'style_invariants')"
required_pattern_rules="$(sf rules_filter "$rules_json" 'required_pattern')"
```

Eval S3's assertion requires consumption through the published `sf_rules_*` API (via the `sf` dispatcher) — no raw inline regex parsing of `mcrule:start` HTML sentinels. The `sf` dispatcher (NOT `sd`) is correct: scaffold-dev consumes scaffold-onboard's published library directly per SPEC §16.2.

### 8.2 Apply against modified files

Compute the work item's modified files from the worktree's staged diff:

```bash
modified_files=()
while IFS= read -r f; do modified_files+=("$f"); done < <(git -C "$worktree" diff --name-only --cached)
```

Then invoke `sd_rules_apply` (lib/rules.sh — scaffold-dev's adapter that walks rule JSON arrays and dispatches per type):

```bash
sd rules_apply "$rules_json" "$worktree" "${modified_files[@]}"
```

`sd_rules_apply` returns 0 if no violations fire; non-zero on first violation, emitting a structured line on stderr: `RULE_TYPE=<t> RULE_NAME=<n> FILE=<path> LINE=<n> MESSAGE=<text>`.

**Halt on first rule violation.** Same discipline as AC halt: the user picks a §12.2 row 3 option, the implementer-agent re-runs with rule context in fix-up handoff, and rule evaluation re-starts on the next pass.

On rule violation: jump to §9.5 (`[rule]`-tagged error + §12.2 row 3 menu).

On no violations: proceed to §9.1 all-pass green summary.

---

## 9. Outcome surfaces

Five mutually-exclusive outcome paths. Exactly one fires per invocation.

### 9.1 All-pass + rules present (S1 / S3 happy path)

Precondition: at least one `auto:` AC executed and passed. If the tuple list was
empty, the §4 zero-AC degrade advisory fires instead of this green summary.

Emit a green verification summary naming each AC and the rule check:

> Work item `<work_id>` verified.
> - AC-1: pass
> - AC-2: pass
> - AC-3: pass
> - Project rules: pass (N rules evaluated against M modified files)
> - Report cross-check: match
>
> Ready for commit + merge.

Then hand control back to the orchestrator (or, when invoked directly, to the user). Do NOT commit, do NOT merge, do NOT edit `report.md`.

### 9.2 All-pass + rules absent (S4 fallback)

Emit the green summary with an explicit rules-absent advisory. The advisory MUST name either "rules" or "R2" so the user can identify what was skipped (eval S4 rejects silent skip):

> Work item `<work_id>` verified.
> - AC-1: pass
> - AC-2: pass
> - AC-3: pass
> - Report cross-check: match
>
> Advisory: no project rules authored in `03-code-patterns.md` — only AC verification ran. Author R2 machine-checkable rules via `/scaffold-onboard` (or `Skill(scaffold-onboard:authoring-machine-checkable-rules)`) to enable rule checks at this gate.
>
> Ready for commit + merge.

Eval S4 also asserts that `sf_rules_*` evaluation functions MUST NOT be called beyond the absence-detection probe — do not spuriously invoke `sf_rules_parse` against a known-empty section.

### 9.3 AC fail (S2 — `[AC]` tag + §12.2 row 1 menu)

Surface the source-tagged error first, then the menu. The literal token `[AC]` (square brackets, no other spelling) is load-bearing per eval S2:

> `[AC]` `<failing_ac_label>` failed: `<failing_cmd>` exited with status `<exit_code>`.
>
> ```
> <first ~200 chars of failing_output>
> ```
>
> Work item `<work_id>` halted at `<failing_ac_label>`. Remaining ACs (`<list>`) not run per halt-on-first-fail.
>
> **Failure-response menu (§12.2 — AC verification fail):**
> 1. **Re-spawn implementer subagent with fix-up handoff** — append a `## Fix-up iteration N` section to `handoff.md` capturing the failure context, then re-invoke `Task(subagent_type="scaffold-dev:implementer-agent", ...)`.
> 2. **Accept partial-with-deferred** — mark `<failing_ac_label>` as deferred-to-follow-up; backlog gets a new work item.
> 3. **Replan work item** — return to spec authoring; reset `handoff.md` and re-run `planning-vertical-slice` for this item.

Then stop and wait. Do NOT auto-select an option, do NOT invoke the Task tool, do NOT mutate `handoff.md` or `report.md` — those are user-selected downstream actions.

### 9.4 Report cross-check mismatch (`[report cross-check]` tag + §12.2 row 2 menu)

This path fires only when §6 found all ACs passing but §7 found the report disagreeing (rare; usually indicates report-authoring drift).

> `[report cross-check]` `report.md` claims `<claimed_outcome>` for `<ac_label>`, but gate observed `<observed_outcome>`.
>
> **Failure-response menu (§12.2 — Report cross-check mismatch):**
> 1. **Re-spawn** — report is likely inaccurate; re-invoke the subagent to re-author.
> 2. **Interrogate via subagent** — re-invoke with prompt: "re-verify `<ac_label>` and re-author `report.md`".
> 3. **Override** — treat as AC fail; apply the row 1 menu (re-spawn / partial-deferred / replan).

Then stop and wait.

### 9.5 Rule fail (S3 — `[rule]` tag + §12.2 row 3 menu)

ACs are reported as passed FIRST so the user can see the failure source is rule-side, not AC-side. The literal token `[rule]` is load-bearing per eval S3:

> Work item `<work_id>`:
> - AC-1: pass
> - AC-2: pass
> - AC-3: pass
> - Report cross-check: match
>
> `[rule]` `<rule_type>` (`<rule_name>`): `<file>:<line>` — `<message>`.
>
> **Failure-response menu (§12.2 — Project rule check fail):**
> 1. **Re-spawn with rule context** in fix-up handoff — append a `## Fix-up iteration N` section to `handoff.md` naming the violated rule + file + line, then re-invoke the subagent.
> 2. **Accept-with-deferred TODO** — mark the violation as deferred; add a TODO in the backlog to address before slice close.
> 3. **Replan if rule is fundamental** — return to spec authoring; the rule may indicate the work item's approach is wrong.

Then stop and wait. Do NOT auto-fix the violation (e.g., no `Edit` on the offending file to swap `import requests` for `import httpx`); the fix-up belongs to the implementer-agent on re-spawn, or to the user on accept-with-deferred.

---

## 10. Bash bookkeeping helpers

This skill never bash-orchestrates judgment work (which menu row applies, how to phrase the source-tagged error, whether the rules-absent advisory belongs above or below the green summary). It calls helpers for I/O and rule evaluation only.

**Manifest (lib/manifest.sh — T3.2):** `sd_manifest_require`, `sd_manifest_get`, `sd_manifest_resolve`.

**Verify (lib/verify.sh — T3.6):** `sd_verify_auto_step <cmd> <expectation> <worktree>` — runs a single `auto:` step and checks the expectation.

**Rules (lib/rules.sh — T3.7):** `sd_rules_apply <rules_json> <worktree> <modified_files...>` — scaffold-dev's adapter; dispatches per rule type and halts on first violation.

**scaffold-onboard's published rules API (`scaffold-onboard/lib/rules.sh`):** `sf_rules_parse`, `sf_rules_filter`, `sf_rules_validate_block`. Source directly from scaffold-onboard's lib path per SPEC §16.2 — scaffold-dev does NOT re-implement parsing.

Implementations live in their respective lib files (Phase 3 tasks). macOS-portable patterns (BSD awk, bash 3.2) required for any inline snippets; prefer calling the helpers over re-inlining shell.

---

## 11. Anti-patterns (do not do these)

- **Continuing AC iteration after the first failure.** Eval S2's assertion is binding — exactly one Bash invocation in the tool-call log when AC-1 fails. Halt immediately.
- **Paraphrasing source-tag tokens.** The literal `[AC]`, `[report cross-check]`, and `[rule]` brackets are load-bearing. Eval S2/S3 reject `(AC)`, `<rule>`, `**AC**`, `[ac]`, or any other spelling.
- **Collapsing the §12.2 menu to fewer than 3 options.** Each failure row has ≥3 user-selectable options (AC fail = 3, report mismatch = 3, rule fail = 3). Eval S2/S3 reject menus with 1-2 options.
- **Auto-selecting a menu option.** The menu is a user decision boundary; surfacing-and-waiting is the entire contract. No `Task(subagent_type="scaffold-dev:implementer-agent", ...)` on a fail turn; no `Edit` to `handoff.md`/`report.md`; no auto-fix to worktree source.
- **Raw inline regex parsing of `mcrule:start` sentinels.** Eval S3 asserts consumption through `sf_rules_*`. Source scaffold-onboard's published lib; do not duplicate the parser.
- **Calling `sf_rules_parse` or `sf_rules_filter` when the rules section is empty.** Eval S4 asserts no `sf_rules_*` evaluation calls beyond the absence-detection probe. The probe (Read or Grep for `<!-- mcrule:start `) is sufficient; do not run zero rules against the diff.
- **Silent skip on rules-absent.** Eval S4 rejects silent skip — emit the §9.2 advisory naming "rules" or "R2". The user must be able to identify what was skipped.
- **Editing `report.md` to "fix" a cross-check mismatch.** Verification is read-only with respect to repo artifacts. The mismatch is surfaced; the user picks row 2's option to re-spawn or interrogate; the implementer-agent re-authors.
- **Committing or merging on green.** The green summary hands control back to the orchestrator (or user). Commit + merge are `planning-vertical-slice` §8.6's lane, not this gate's.
- **Removing worktrees on fail.** SPEC §11 defers worktree removal to slice close. The worktree survives every halt — preserves state for user inspection and the re-spawn path.
- **Running `auto:` commands outside the worktree.** Each command MUST execute scoped to `$worktree` (via `cd "$worktree" && <cmd>` or `git -C "$worktree" ...`). Running in the canonical root or the AI workspace produces false-greens (the implementer's staged-but-uncommitted changes don't exist outside the worktree).
- **Reading manifest fields via raw `jq`.** All manifest reads route through `sd_manifest_get` / `sd_manifest_resolve` — mirrors `planning-vertical-slice` §3.1 discipline.
- **Treating `user:` demo steps as ACs.** `user:` lines are manual demo steps verified at slice-close per `closing-vertical-slice` §14.2. Skip them silently in this gate.
- **Letting this body exceed 500 lines.** Hard cap per superpowers:writing-skills Pass D guidance.

---

## 12. Notes on tool boundaries

- **You** (Claude reading this skill body) make every judgment call: how to phrase the source-tagged error, which menu row matches the observed failure, whether the rules-absent advisory belongs above or below the green summary, when to ask "which work item?" vs. consult the cursor.
- **Bash helpers** (`lib/verify.sh`, `lib/rules.sh`, `lib/manifest.sh`) handle pure I/O: AC step execution + expectation evaluation, rule dispatch, manifest reads.
- **`scaffold-onboard/lib/rules.sh`** owns the mcrule parser and the four v0.2 rule-type schemas. Consume `sf_rules_parse` + `sf_rules_filter` directly; do not re-implement.
- **`planning-vertical-slice`** owns the orchestrator lane: spec authoring, worktree creation, subagent dispatch, commit + merge after this gate returns green. Hand control back to it on every outcome path.
- **`scaffold-dev:implementer-agent`** (subagent) owns work-item execution INSIDE the worktree. It stages changes; the orchestrator commits after this gate passes. Verification gates between subagent return and commit.
- **The user** picks the §12.2 option on every fail. You never auto-advance past a decision boundary; you never re-spawn the subagent on your own; you never edit `report.md` or `handoff.md` to "patch" a mismatch.

When in doubt, prefer surfacing-and-waiting over acting. The verification gate's value is the deterministic halt: items 1..N verified-and-merged, item N+1 halted with menu surfaced, items N+2.. not started. Worktrees and branches preserved for inspection. Every halt is a user decision boundary.
