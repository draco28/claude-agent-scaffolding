---
name: closing-vertical-slice
description: Run the three-layer slice-close ceremony — auto-demo (halt-on-first-fail), manual-demo, architect-critic review at close depth, `retrospective.md` authoring, memory-bank harvest sweeping `report.md` + handoffs with `[report]`/`[handoff]` source tags, then worktree + branch cleanup (only after harvest). Also owns sprint-close handoff cleanup on the final slice. Use this when the user says `close VS-N.M.K`, `slice close`, `wrap up the slice`, or `run slice-close ceremony`.
---

# closing-vertical-slice

You are the slice-close ceremony for scaffold-dev v0.1's vertical-slice lifecycle. After `planning-vertical-slice` has shepherded all rounds to completion (all work items committed + merged, worktrees + branches still present per §11 M2), this skill runs the three-layer close: auto-demo → manual-demo → architect-critic adversarial review at close depth → retrospective authoring → memory-bank harvest (with handoff sweep) → worktree + branch cleanup.

The ceremony order is binding. The §11 M2 marker — worktrees + branches removed ONLY after harvest completes — is the load-bearing discipline this body enforces. Halt-on-first-auto-demo-failure preserves worktrees for inspection (eval S2). Warn-and-proceed on architect-critic absence keeps the ceremony moving without blocking (eval S3). Source-tagged harvest with literal `[report]` / `[handoff]` brackets and the provenance trailer carries SPEC §15.2's 8-step contract through eval S4.

Bash helpers (`lib/manifest.sh`, `lib/render.sh`, `lib/worktree.sh`, `lib/compose.sh`, `lib/harvest.sh`) do the bookkeeping (see §16); the judgment work — demo-criterion evaluation, harvest categorization, menu phrasing — happens here, in conversation.

This skill is the slice-close terminal step. It does NOT plan slices (that's `planning-vertical-slice` per §5), does NOT verify per-work-item ACs (that's `implementation-checking` per §12.1), and does NOT author the work-item bodies (that's the `scaffold-dev:implementer-agent` subagent body via `executing-work-item` per §6). It is invoked at the end of the slice when all rounds complete, either by a natural-language trigger ("close VS-N.M.K") or from `/orchestrate`'s close phase (there is no dedicated `/close-slice` command — see §13).

---

## 1. Overview

When invoked, you, in order:

1. **Pre-flight (§3):** discover the manifest (refuse fail-fast if absent); resolve the VS-id; field-read `sprint_id` + locate the slice dir; confirm all work items are at complete status.
2. **Parse demo criteria (§4)** from the VS README per §14.1 grammar.
3. **Layer 1 — auto-demo (§5):** run each `auto:` in canonical (NOT a worktree), evaluate, **halt on first fail**.
4. **Layer 2 — manual-demo (§6):** surface each `user:` step, capture pass/fail/partial.
5. **Layer 3 — architect-critic (§7):** probe; invoke at close depth if present (sync or opt-in async per the `review_gate`), else warn-and-proceed.
6. **Retrospective (§8):** render the 7-section `retrospective.md` (BEFORE harvest).
7. **Harvest (§9):** sweep `report.md` + slice-scoped handoffs; surface `[report]`/`[handoff]` candidates; apply accepted items via `sd harvest_apply`.
8. **Cleanup (§10, M2):** remove worktrees + branches — ONLY after harvest. Then sprint-close sweep on the final slice (§11), the slice→sprint PR under `pr_hierarchical` (§10a), the §12 active-context reconcile, and the §14 closing message.

Phase 1 RED→GREEN: this body's behavior is contracted by `scaffold-dev/evals/closing-vertical-slice.md` — the six scenarios there are the binding spec.

---

## 2. When to use

**Trigger phrases (description-match):**

- `close VS-N.M.K` (e.g., `close VS-1.1.1`)
- `slice close`
- `wrap up the slice`
- `run slice-close ceremony`
- `close VS-N.M.K` (natural-language trigger) or `/orchestrate`'s close phase (see §13 for invocation + the `--gate` override)

All four phrase forms are load-bearing in the description block above — the four eval scenarios trigger via description-match on each, so do not paraphrase any of them in your acknowledgement.

**Do NOT auto-invoke when:**

- Any work item in the slice has NOT yet returned `mode: complete` from its implementer-agent — route back to `planning-vertical-slice` §8 to finish the round.
- Any work item has been verified but NOT committed + merged — `implementation-checking` returned green but the orchestrator's commit + merge step (§8.6) has not run; route back.
- The slice directory does not exist or contains no work-item subdirs — surface the missing-slice error (§3.4) and stop.
- The user wants to *plan* a new slice (that's `planning-vertical-slice`) or *execute* a work item (that's the implementer-agent subagent).

If the user types something ambiguous like "we're done with VS-1.1.1", confirm: *"Run the slice-close ceremony for VS-1.1.1 (auto-demo → manual-demo → architect-critic → retrospective + harvest → worktree cleanup)?"*. The ceremony is destructive at the cleanup step — never auto-advance past the user's intent confirmation when the trigger phrase isn't explicit.

---

## 3. Pre-flight

Before any demo step, validate prerequisites in this order. Any failure surfaces the error string and stops.

### 3.1 Manifest discovery (refuses fail-fast)

Call `sd_manifest_require` (lib/manifest.sh). If absent, surface this verbatim refusal and stop:

> scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first.

The literal `/init-workspace` and `/pair-workspace` slash-command tokens are load-bearing (mirrors `planning-vertical-slice` §3.1 + `implementation-checking` §3.1). On refusal, do NOT read the VS README, run any `auto:` command, invoke architect-critic, or touch any worktree.

All scaffold-dev lib calls go through the `sd` dispatcher (`scaffold-dev/bin/sd`, on `$PATH`; its bash shebang forces a bash runtime regardless of the calling shell):

```bash
if ! sd manifest_require 2>/dev/null; then
  printf '%s\n' "scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."
  exit 0
fi
```

Never read manifest fields via raw inline `jq`. All manifest reads route through `sd_manifest_get` / `sd_manifest_resolve`.

### 3.2 Resolve the VS-id

Resolution priority:

1. **Explicit id** in the user message (e.g., `close VS-1.1.1`) — match the full 3-part `VS-<phase>.<sprint>.<slice>` token and normalize to the `VS-`-prefixed form (`vs_id="VS-1.1.1"`).
2. **Active-context cursor** — read `<ai-workspace>/.claude/memory-bank/05-active-context.md` for the in-flight slice; use that when the message is ambiguous (e.g., `slice close`, `wrap up the slice`).
3. If neither produces an id, ask: *"Which slice? (e.g., `VS-1.1.1`)"* and wait.

### 3.3 Read manifest fields + field-read the slice

```bash
ai_workspace="$(sd manifest_get '.ai_workspace.root')"
canonical="$(sd manifest_get '.canonical.root')"
worktrees_dir="$(sd manifest_resolve "$ai_workspace" "$(sd manifest_get '.during_dev.worktrees_dir')")"
handoffs_dir="$(sd manifest_get '.routing.handoffs_dir')"   # resolves to <ai-workspace>/.workspace/handoffs/ in v0.1
sprint_dir_template="$(sd manifest_get '.during_dev.sprint_dir_template')"
```

Field-read the slice's `sprint_id` from the published structured roadmap — the same contract `planning-vertical-slice` uses. Never split it out of the slice id:

```bash
roadmap_state="$(sd roadmap_state_path)"
sprint_id="$(sd roadmap_slice_sprint_id "$vs_id")"   # e.g. "1.1" for VS-1.1.1
```

### 3.4 Locate the slice directory

The sprint segment is the field-read `sprint_id`; the kebab suffix was chosen at planning time and isn't field-read here, so locate the existing dir by glob (`vs_id` is the full 3-part id, e.g. `VS-1.1.1`):

```bash
slice_root="$(ls -d "${ai_workspace}/docs/specs/sprint-${sprint_id}/${vs_id}-"*/ 2>/dev/null | head -1)"
slice_root="${slice_root%/}"
# → …/docs/specs/sprint-1.1/VS-1.1.1-<kebab>
```

If `slice_root` is empty or contains no `work-*/` subdirectories, surface:

> Slice `<vs_id>` not found at `<resolved-path>`. Has `planning-vertical-slice` authored this slice yet?

Then stop. Do NOT auto-create the directory; spec authoring is the orchestrator's lane.

### 3.5 Confirm round-complete state

Read each work item's `report.md`. If any report has `Status: gaps-surfaced`, `Status: in-progress`, or is empty, surface:

> Work item `<work_id>` not at complete status (`<status_observed>`). Route back to `planning-vertical-slice` to finish the round before closing the slice.

Then stop. The ceremony depends on all work items having committed + merged outputs.

---

## 4. Demo-criteria parse (per §14.1 grammar)

Read `${slice_root}/README.md`. Locate the demo-criteria block (rendered into the README at `planning-vertical-slice` §6 from the ROADMAP's `auto:`/`user:` lines). Parse each demo line directly in the orchestrator — no lib parser is needed, because parsing a two-field line is trivial and the evaluation is agent-driven anyway.

For each line under the `## Demo criteria` (or `##### Demo criteria`) section, strip the leading `- [ ] ` checkbox and check the prefix:

- Lines starting with `auto: ` → split on the literal ` → expected: ` (U+2192 arrow, NOT ASCII `->`) to yield `(command, expectation)`.
- Lines starting with `user: ` → split the same way to yield `(action, expectation)`.
- Lines not matching either prefix → skip (section headers, blank lines, etc.).

**Strip the command's surrounding backticks** after the split (then trim whitespace) so the tuple holds the bare command. Skipping this is a real bug: §5's `eval "$command"` on a still-backticked string runs the inner text as command substitution and fails slice-close even though the demo passes.

Build two ordered lists: `auto_steps` (the `auto:` tuples in declared order) and `user_steps` (the `user:` tuples in declared order). If both lists are empty, surface:

> VS README at `<resolved-path>` declares no demo criteria. Author at least one `auto:` or `user:` line (per §14.1 grammar) before closing the slice.

Then stop.

---

## 5. Layer 1 — auto-demo execution (halt on first fail)

Iterate `auto_steps` in declared order. For each `(command, expectation)`:

```bash
cd "$canonical"   # auto-demo runs in CANONICAL post-merge state, NOT in any worktree
result_stdout="$(eval "$command" 2>&1)"; result_exit=$?
```

The `cd "$canonical"` is binding — eval S1's judge confirms either the absence of any `cd <worktree>` prefix OR the explicit presence of a canonical-root marker. Auto-demo against a work-item worktree produces false-greens (the worktree's branch may be at a pre-merge HEAD).

Under `merge_mode=pr_hierarchical` the slice's work lives on the slice branch, not `default_branch` — check out the slice branch in canonical FIRST (guard the checkout; HALT on failure, never demo against an unverified checkout). See `references/pr-hierarchical-close.md`. The default `direct` mode needs no checkout.

Evaluate `expectation` using a **run-then-judge** approach:

- If `expectation` is an **exit-code form** (`exit 0` or `exit <N>`): **deterministic** — pass iff `result_exit == N`. This is a mechanical fact; no agent judgment needed. **For `exit 0` only (#74):** after the exit-code check passes, also run `printf '%s' "$result_stdout" | sd zero_tests_guard "$command"` (the log is piped via **stdin**, not argv, so a verbose run can't exceed `ARG_MAX`); if it returns non-zero, a recognized test runner (pytest/go test/cargo test/nextest/jest/vitest/node --test) exited 0 having collected **zero** tests — a vacuous green. Treat it as a **fail** (the halt-on-first-fail path below) with a "zero tests collected — fix the filter/path" reason. Allowlist-only + fail-soft: an unrecognized command is unaffected, and `exit <N>` (N≠0) negative-test steps are exempt.
- If `expectation` is any **content form** (`output contains …`, `output matches …`, `count > 0`, `> 5 rows`, or free-form prose): the orchestrator **judges** whether `result_stdout` satisfies the stated expectation and records a one-line reason. No bash substring or arithmetic parsing.

Record each outcome in the VS README's `## Demo verification` section (append if absent), one line per step, including the agent's reason:

```
- [x] auto: <cmd> → expected: <exp> → observed: pass — <one-line reason>
- [x] auto: <cmd> → expected: <exp> → observed: fail — <one-line reason or stderr excerpt>
```

**Halt-on-first-fail is binding.** On any fail:
- Do NOT run the remaining `auto:` lines.
- Do NOT surface `user_steps`.
- Do NOT invoke architect-critic.
- Do NOT author `retrospective.md`.
- Do NOT run harvest.
- Do NOT remove any worktree or delete any branch.
- Mutate ONLY the "Demo verification" line for the failing step (the rest of the README is untouched).

Surface a failure report naming: (a) the verbatim `auto:` line from the VS README so the user can identify the failing step, (b) the command that was run, (c) the observed exit code, (d) a captured stderr/stdout excerpt (~200 chars). Then present the recovery menu (§12.2 row adapted for slice-close auto-demo fails):

> **Recovery menu (§12.2 — slice-close auto-demo fail):**
> 1. **Re-author the demo step** — the criterion is wrong; return to scaffold-onboard's `Skill(scaffold-onboard:authoring-vertical-slice-demo)` (or `/plan-roadmap --refine-slice VS-<N.M.K>`) to revise.
> 2. **Accept-with-deferred** — slice closes with the failing step marked deferred; the slice must still be demoable despite the caveat (per §14.4 close-with-deferred). Add a follow-up work item to the backlog.
> 3. **Re-spawn implementer subagent for fix-up** — the implementation is wrong; re-invoke the offending work item's implementer-agent against the failing area, then re-run the slice-close ceremony.

Then stop and wait. Do NOT auto-select an option (option 3 in particular requires a `Task` dispatch which is a user-gated action, not ceremony-driven). The judge in eval S2 explicitly checks for ≥3 distinct menu options matching this shape and rejects collapse to fewer; eval S2 also asserts no `Task` invocation on the halt turn.

On all-pass: proceed to §6.

---

## 6. Layer 2 — manual-demo execution

Iterate `user_steps` in declared order. For each `(action, expectation)`:

1. Surface the step verbatim to the user with the expected outcome quoted:

   > **Manual demo step <K>:** `<action>` → expected: `<expectation>`. Run this and report back: pass / fail / partial + a note.

2. Wait for the user's response. Capture pass/fail/partial + the user's verbatim note.
3. Record in the VS README's "Demo verification" section:

   ```
   - [x] user: <action> → expected: <exp> → observed: pass — <user note>
   ```

Eval S1's judge confirms the manual-demo step appears in the assistant transcript with the expected outcome quoted AND that the target waits for / captures the user response before proceeding to Layer 3. Auto-advancing past a `user:` step (or paraphrasing the expected outcome away) fails the assertion.

**Partial / fail outcomes:** if the user reports `fail` or `partial`, treat it the same way as Layer 1's fail — halt, do NOT invoke architect-critic, do NOT author retrospective, do NOT run harvest, do NOT touch worktrees. Surface the same 3-option recovery menu (§5), adapted for manual-demo:

> 1. Re-author the demo step · 2. Accept-with-deferred (slice closes with caveat) · 3. Re-spawn implementer for fix-up against the manual flow.

On all-pass across all `user_steps`: proceed to §7.

---

## 7. Layer 3 — architect-critic adversarial review (in-conversation, §16.3 moment 2)

After both demo layers pass, invoke architect-critic at close depth.

### 7.0 Review-gate resolution (#39 Phase B — opt-in async)

The opt-in `review_gate` (manifest `.review_gate`, default `off`) decides whether the slice-close audit runs **synchronously** (today's behavior) or as an **async dispatch-and-defer** job (so a slow close-depth Codex audit does not block the close). Resolve the gate FIRST:

1. Resolve the gate, honoring any per-invocation `--gate` override carried from §13:
   ```bash
   gate_override_args=()
   [[ -n "${gate_override:-}" ]] && gate_override_args=(--gate "$gate_override")
   gate="$(cd "$ai_workspace" && sd review_gate_resolve "${gate_override_args[@]}")"
   ```
   → `off | slice_close | spec_close | both`. **Resolve from the AI-workspace root:** the §5 auto-demo loop `cd`s into `$canonical`, but the pairing manifest (and its `.review_gate`) lives under the AI workspace. `sd review_gate_resolve` walks up from the CWD, so resolving from `$canonical` would find no manifest and default to `off` — silently skipping an opted-in gate. Precedence: `--gate` override > manifest `.review_gate` > `off` (an invalid value fails loud). Default `off` = **today's behavior** exactly (the synchronous review in §7.2).
2. `cap="$(sd compose_detect_architect_critic 2>/dev/null || true)"` → `v0.3 | v0.2 | absent` (§7.1). The `|| true` is load-bearing: the probe prints `absent` but **exits 1 by design** when architect-critic is missing, and an unguarded command substitution would abort a `set -e` block before the §7.3 warn-and-proceed branch runs. This probe is **advisory only** and **host-agnostic**: it reports what is installed across *all* plugin caches, but only the **active host's** architect-critic is actually invocable here. Two consequences: (a) **Runnability** — if the probe reports present but `Skill(architect-critic:critiquing-spec)` is not runnable in the active host (e.g. it lives only in the *other* host's cache), treat it as **`absent`** and take §7.3 — never invoke a skill the active host cannot resolve. (b) **Version/host** — a mixed-version cache can never force a phantom background job; the react-to-return step (§7.2a step 4) degrades any non-async outcome to a synchronous review.

Route (the slice-close attach point fires for `slice_close`/`both` only — `spec_close` gates the *spec* moment, not this one):

- `cap=absent` (or reported-present-but-not-runnable-in-the-active-host, per the runnability check above) → **§7.3** (warn-and-proceed), regardless of gate.
- gate ∈ {`slice_close`, `both`} (architect-critic present) → **§7.2a** — request an async close-depth audit and react to what architect-critic actually does. Async is **Claude-host** → Codex-adversary only; under Codex-host or architect-critic v0.2 the very same call runs a **synchronous** close-depth review instead (§7.2a step 4).
- gate ∈ {`off`, `spec_close`} → **§7.2** synchronous close-depth review (today's behavior).

### 7.1 Detection (filesystem probe)

Call `sd_compose_detect_architect_critic` (lib/compose.sh). It walks `~/.claude/plugins/cache/*/architect-critic/*/skills/{critiquing-spec,managing-async-critique}/SKILL.md` and prints `v0.3` (async-capable — the `managing-async-critique` skill is present), `v0.2` (sync-only — only `critiquing-spec`), or `absent`. This is NOT a composition.json read — scaffold-dev does not maintain a composition.json cache (per SPEC §16.3). The probe MUST be observable in the tool-call log (eval S3 asserts a Bash invocation listing or globbing the cache path appears, even when the probe returns absent).

### 7.2 Invocation — synchronous (when present, S1 contract)

When routed here by §7.0 (gate `off`, or `spec_close` which gates the *spec* moment, not this one) — **synchronous** close-depth review (the default; gate `off` preserves this exactly). With gate `off`, **everything** lands here (including `v0.2`/Codex-host) — that is the default. Only when `review_gate` is `slice_close`/`both` do the `v0.2` and Codex-host cases route through §7.2a instead, whose react-to-return step degrades to a synchronous close-depth review:

1. Announce: *"Demos passed — invoking architect-critic for the slice-close adversarial review at close depth. Type `skip` to bypass."*
2. End the turn and wait. If the user types `skip` (case-insensitive): log the skip in `retrospective.md`'s critic section and proceed to §8.
3. Otherwise, invoke `Skill(architect-critic:critiquing-spec)` with:
   - `target=slice`
   - `depth=close` (per ac v0.2 §5.1 — close-depth is the heavier audit, includes optional Codex fresh-frame invocation; distinct from the lighter `author` depth used at `planning-vertical-slice` §7.2 moment 1)
   - **Context:** the slice's combined diff (from the VS-start commit to canonical HEAD) + the VS README (with demo-verification section populated) + all work-item `spec.md` paths.
   - Context note: this is the scaffold-dev SPEC §16.3 moment 2 (slice-close adversarial), distinct from the moment 1 spec-author audit at slice-plan time.
4. architect-critic runs its own sequential rebuttal cycle with T=4 concession scoring; the user resolves challenges in conversation; eventually control returns.
5. When control returns: capture the critic's findings + the user's rebuttal outcomes into a section of `retrospective.md` (§8).

**Eval contract (S1):** the `Skill(architect-critic:critiquing-spec)` invocation MUST appear in the tool-call log exactly once AND MUST appear AFTER both `auto:` Bash invocations AND after the manual-demo user response is captured. The judge verifies the relative position. No `Write` to `inbox/` or `outbox/` paths — legacy file IPC was removed in architect-critic v0.2 (SPEC §16.3) and any such write fails the assertion.

### 7.2a Invocation — async dispatch-and-defer (review_gate=slice_close|both) [#39 Phase B]

The gate runs the **same** close-depth adversarial review, but requests background dispatch so the slice close is not blocked on a slow Codex audit. **Dispatch-and-defer:** when async is available the audit runs in the background and the rebuttal is consolidated later via resume; otherwise the very same call degrades to a **synchronous** close-depth review (never a broken or phantom job). The gate **reacts to what architect-critic actually returns** rather than predicting host/version.

1. Announce + usage warning: *"review_gate is on — requesting a close-depth architect-critic audit, dispatched as a background job when supported (**Claude-host** + architect-critic v0.3) and run synchronously otherwise. This consumes Codex/subscription usage. Type `skip` to bypass."*
2. End the turn and wait. On `skip` (case-insensitive): carry a *"skipped — review_gate bypassed by user"* note forward to §8 (do NOT write `retrospective.md` here — it is rendered in §8; §8 step 3 records the note) and proceed to §8.
3. **Build the review bundle (one tested call).** architect-critic's async/CLI path reads exactly ONE artifact file (`critiquing-spec` Step 1a), so the full slice-close context must be assembled into a single artifact. The mechanical assembly is the tested helper `sd review_gate_bundle` (`lib/review_gate.sh`) — it writes the bundle **under the slice dir** (a trusted git root, never `/tmp`, so architect-critic's async target-root pre-flight accepts it), includes the slice diff **only when non-empty** (omitted in the default `direct` merge mode where the slice is already merged into the default branch so `merge-base == HEAD` — tracked as #76), and appends each `HEADING PATH` section (a missing file is noted, not fatal):
   ```bash
   bundle="$(sd review_gate_bundle --slice-root "$slice_root" \
     --title "Slice-close review bundle: $vs_id" \
     --diff-root "$canonical" --diff-base "$base_branch" \
     "VS README" "$slice_readme" \
     "spec: <work-id>" "<work-item spec.md>" \
     "report: <work-id>" "<work-item report.md>")"   # repeat the spec/report pairs per work item
   ```
   `$base_branch` = the canonical default branch (`canonical.default_branch`) or the sprint integration base under `pr_hierarchical`. The helper echoes the bundle path; step 5 removes it after dispatch (a dotfile, kept out of `work-*/spec.md` globs, never committed).
4. Drive architect-critic through its **real CLI contract** — informal parameters do NOT set async (`async_mode` is read only from `--async` in `$ARCHITECT_CRITIC_ARGS`; see [[feedback_slash_command_dollar_n_bug]]). **Export** the args through the same env-var bridge `/critique` uses — a plain (non-exported) assignment is NOT visible to the `critiquing-spec` bash that reads `$ARCHITECT_CRITIC_ARGS`. Pass the bundle as an explicit, quoted `--spec` path (Step 1a checks `--spec` before any positional, and quoting guards a bundle path that contains spaces): `export ARCHITECT_CRITIC_ARGS="--spec \"$bundle\" --close --async"`. Then invoke `Skill(architect-critic:critiquing-spec)` **EXACTLY ONCE**. (`--close` = close depth; `--async` = defer-to-resume, honored only for Claude-host + v0.3 and otherwise ignored, running synchronously.)
5. **React to the return — three outcomes** (do NOT assume async happened); `rm -f "$bundle"` once the call returns (the artifact is fully consumed at dispatch):
   - **Async dispatched** — architect-critic returns a background **job handle `<id>`** and STOPS without a rebuttal: **carry the job `<id>` + resume command forward to §8** — do NOT write `retrospective.md` here (it does not exist yet; §8 renders it from the template and would overwrite an early write). §8 step 3 records the async handle in the Architect-critic findings section. Surface the status and **PROCEED to §8** (do NOT block, do NOT consolidate now):
     > Slice-close audit running in the background as job `<id>`. The close proceeds now; resume with `/critique-jobs resume <id>` before final sign-off to fold both adversaries into one rebuttal. If it never completes (stalled/capped/failed), `/critique-jobs status <id>` shows the disposition — the close is not blocked either way.
   - **Ran synchronously** — architect-critic instead completed its rebuttal cycle inline (no job handle: the Codex-host, architect-critic v0.2, or foreground-size-hint cases): treat it exactly as §7.2 — **carry the critic's findings + rebuttal outcomes forward to §8** (do NOT write `retrospective.md` here — §8 renders it from the template; §8 step 3 records them in the Architect-critic findings section), then proceed to §8. Do NOT record a `/critique-jobs resume` pointer — there is no job.
   - **Pre-flight hard-fail** — under Claude-host + v0.3 but Codex uninstalled/unauthed/untrusted, `critiquing-spec` Step 6-async HARD-FAILS with remediation and **no** silent foreground fallback, so it returns NEITHER a job handle NOR a rebuttal. Do NOT stall: surface the remediation verbatim, note that `/critique-doctor` diagnoses readiness and that a synchronous review is available by re-running without `--async`, **carry a *"skipped — async pre-flight unmet"* note forward to §8** (do NOT write `retrospective.md` here — §8 renders it; §8 step 3 records the note), and **PROCEED to §8** (the gate is non-blocking by contract). Re-run synchronously only if the user asks.

**Eval contract (S1 still holds):** still EXACTLY ONE `Skill(architect-critic:critiquing-spec)` invocation, after both `auto:` Bash invocations and after the manual-demo response — only driven through the exported `ARCHITECT_CRITIC_ARGS="--spec \"$bundle\" --close --async"`. No `Write` to `inbox/`/`outbox/`.

### 7.3 Absent / warn-and-proceed (S3 contract)

If `sd_compose_detect_architect_critic` returns `absent`, emit ONE warning and proceed (do NOT block, do NOT prompt the user to install, do NOT retry the probe):

> architect-critic not detected — adversarial review skipped. Install architect-critic v0.2+ via `/plugin install architect-critic` for slice-close audit at this moment.

The warning MUST reference either `architect-critic` (plugin name) OR `adversarial review` (capability name) so the user can identify what was skipped. Eval S3 explicitly rejects silent skip AND rejects a blocking error. Proceed to §8.

---

## 8. Retrospective authoring (per §16b 7-section format)

Render `templates/slice-retrospective.md.tmpl` into `${slice_root}/retrospective.md` via `sd_render`. The 7 sections (per SPEC §16b):

1. **Slice metadata** — VS-id, name, sprint, start date, close date, work-item count, round count.
2. **Demo verification results** — the populated "Demo verification" block from the VS README (auto-demo outcomes + manual-demo outcomes with user notes).
3. **Architect-critic findings** — both moments: moment-1 spec-author audit (cached from `planning-vertical-slice` §7) + moment-2 slice-close adversarial (captured in §7.2 above), each with their challenges and the user's resolutions. If a moment was skipped (architect-critic absent), note "skipped — architect-critic not detected" in that subsection. **If the moment-2 audit was dispatched async (§7.2a, review_gate) and not yet resumed,** this is the durable home for the job handle carried forward from §7.2a: record `dispatched async as job <id> — resume with /critique-jobs resume <id> to fold both adversaries into one rebuttal` (so the resumable pointer survives this render rather than being written before the file exists). If it was dispatched async but pre-flight hard-failed, note "skipped — async pre-flight unmet (`/critique-doctor`)". If the gate was bypassed by the user (`skip` at §7.2a), note "skipped — review_gate bypassed by user". (All §7.2a outcomes are *carried forward* and recorded here so the template render does not clobber an early write.)
4. **Memory bank harvest** — placeholder; §9 fills it after harvest completes.
5. **Deviations + deferrals** — anything that landed as accept-with-deferred during demo layers, plus any cross-cutting deviations from the original spec discovered during the rounds.
6. **Lessons learned** — free-form observations the orchestrator + user captured.
7. **Reference index** — paths to the VS README, all work-item `spec.md` + `report.md` + `handoff.md`, all `vs-N.M.K-*.md` handoffs swept in §9, the retrospective itself.

Write the file BEFORE harvest runs (so the harvest step can append to section 4 in-place). Eval S1 asserts the `Write` of `retrospective.md` appears AFTER the architect-critic invocation in tool-call order, and BEFORE the harvest Reads of report/handoff files — preserve that ordering.

---

## 9. Memory-bank harvest (§15.2 8-step flow)

> Harvest is the slice-close memory-bank write event per the cadence policy (`memory-bank/WORKFLOW.md` → **Memory-bank update cadence**). This section is the operative 8-step order; **`references/harvest-mechanics.md`** holds the categorization routing detail, the lean-index check mechanics, a worked surface example, and the `sd harvest_apply` payload schema + provenance-trailer format.

The harvest is the heart of the slice's memory-bank promotion contract. Eight steps, in order:

1. **Read all work-item `report.md`.** Iterate `${slice_root}/work-*/report.md` (Read tool). Eval S1 + S4 assert ALL reports appear in the Read log.
2. **Read all slice-scoped handoffs.** Glob `${handoffs_dir}/${vs_slug}-*.md` and Read each match (Read tool, not `cat`). The glob is **slice-scoped** — it matches `vs-1.1.1-*.md` but NOT `sprint-1-context-bloat-c3d4.md`; eval S1 + S4 reject reading a sprint-scoped handoff:
   ```bash
   vs_slug="vs-${vs_id#VS-}"
   for handoff in "${handoffs_dir}/${vs_slug}"-*.md; do
     [[ -f "$handoff" ]] || continue
     # Read the handoff file (Read tool)
   done
   ```
3. **Extract promote candidates.** From each `report.md`: the **"Suggestions for memory bank"** section (free-form prose, **agent-read not machine-parsed** — the SS-4/#52 AWK parsers are deleted; you are the sole extraction authority). From each handoff: **section 4 — "What's NOT in memory bank yet"**. Either may be empty.
4. **Categorize by target file** (per `references/harvest-mechanics.md`): caveats/gotchas → `09-known-issues.md`; decisions/advisory patterns → `10-decisions-log.md`; an **enforceable** rule → route to `Skill(scaffold-onboard:authoring-machine-checkable-rules)`, never a raw `03` append. Spec-derived files are never targets (`sd harvest_apply` reroutes + warns). Run the **lean-index check** before proposing a target — if the candidate restates a tracked `DOC §anchor`/ADR/`#issue`, surface a pointer (not prose), confirm it resolves (`sd citations_check_anchor` / `sd citations_check_adr`), and length-lint it (`sd harvest_lint_length`); see the reference for the pointer forms.
5. **Surface candidates with source-tag prefix.** Numbered list; each item's first line MUST start with the literal `[report]` or `[handoff]` — the square brackets are load-bearing per eval S1 + S4 (`(report)`, `<handoff>`, `[Report]` all fail). Show the proposed target per item; ask accept / edit / reject. (Worked example in the reference.)
6. **Consume per-item decisions** — `accept` / `edit: <new text>` / `reject`, per-item or batch (`accept all`, `accept 1,2; edit 3; reject 4`).
7. **Apply with the provenance trailer.** Build the accepted-items JSON array (schema in the reference) and apply in one call — `sd harvest_apply` is the **single mechanical write authority** (exact trailer, idempotency, spec-derived reroute); never hand-author the trailer:
   ```bash
   sd harvest_apply "$accepted_json" "VS-N.M.K"
   ```
   Each accepted item MUST carry `target_file` and a `source:` field matching its origin exactly (`report` vs `handoff`) — eval S4 rejects missing/mis-labeled source. `reject` items are omitted from the array (dropped, no write).

### 9.8 Step 8 — Record harvest outcomes in retrospective.md

Append to section 4 of `${slice_root}/retrospective.md`:

- For each accepted item: source-tag + target file + status `applied` (or `applied-with-edit` if the user edited).
- For each rejected handoff item: source-tag + status `left in handoff` (the item stays in the handoff doc — handoffs are NOT swept-and-deleted at slice close; they persist as historical artifacts per §6b.4 chain model).
- For each rejected report item: status `dropped`.

Eval S4 explicitly checks that the retrospective's harvest section names at least the promoted items with their source AND notes any item "left in handoff" per §15.2 step 8 — distinguishing report-origin from handoff-origin items in the prose is part of the contract.

---

## 10. Cleanup (M2 marker enforcement)

ONLY AFTER §9 step 8 completes successfully, remove worktrees + delete branches.

### 10.1 Worktree removal

For each work item in the slice:

```bash
shopt -s nullglob
worktree_matches=("${worktrees_dir}/sprint-${sprint_id}/work-${work_id}-"*)
shopt -u nullglob
if [[ "${#worktree_matches[@]}" -ne 1 ]]; then
  printf 'Worktree cleanup for %s matched %s paths under %s/sprint-%s/\n' \
    "$work_id" "${#worktree_matches[@]}" "$worktrees_dir" "$sprint_id"
  exit 0
fi
sd worktree_remove "${worktree_matches[0]}"
# Runs: git worktree remove "${worktree_matches[0]}"
# Then: git branch -D "${branch_name}"
```

`sd_worktree_remove` halts on failure (worktree has uncommitted changes, branch is checked out elsewhere). If a removal fails, surface the failure verbatim and stop — leave the remaining worktrees intact for inspection. The user may resolve and re-invoke this skill's cleanup phase, or accept partial cleanup.

**Eval M2 enforcement (S1 + S4):** any `git worktree remove` Bash invocation MUST appear in the tool-call log AFTER the `Write` of `retrospective.md` AND after all harvest-step Reads of report.md + handoff files. If any `git worktree remove` or `git branch -D work-N.NN-*` invocation precedes the retrospective Write OR precedes any harvest Read, the scenario FAILS. Eval S2 enforces the inverse: on auto-demo halt, NO `git worktree remove` invocation may appear at all — worktrees stay preserved for user inspection.

### 10.2 Branch deletion

Branch deletion is bundled into `sd_worktree_remove` per `lib/worktree.sh`'s contract. After §10.1 completes, all `work-N.NN-*` branches are gone. Final filesystem state shows `${worktrees_dir}/sprint-${sprint_id}/work-*` directories absent and `git branch` listing in canonical does not contain any `work-*` branch.

---

## 10a. Open the slice→sprint PR (pr_hierarchical only)

Runs only when `sd merge_mode` == `pr_hierarchical`, AFTER §9 harvest + §10 cleanup: push the integration branches, compose the PR body (slice README + architect-critic summary + linked refs), `sd pr_open`, then the agent-driven pre-merge gate (`sd pr_state` + `sd pr_review_comments` → reason → surface → ask; merge via `sd pr_merge` only on explicit ack). If left open for async CI/review, HALT before §11 and do NOT run sprint-close cleanup or claim the slice is closed; never busy-wait. Full steps in `references/pr-hierarchical-close.md`. The default `direct` mode skips this section entirely (work items already merged into `default_branch` at §8.6).

---

## 11. Sprint-close branch (final slice of the sprint)

If this is the FINAL slice of its sprint — detected via `next_vs_id="$(sd roadmap_next_slice "$vs_id")"` (empty ⇒ final; the same shared lookup §12.1 uses) with `next_sprint_id="$(sd roadmap_next_sprint "$sprint_id")"` — run the sprint-close cleanup per §6b.6: sweep handoffs in `${handoffs_dir}/` that lack a `carry_forward: true` marker (carry-forward ones survive into the next sprint), then surface the swept/preserved counts. Full steps in `references/sprint-close-cleanup.md`. The sprint-level retrospective is out of scope here — `writing-sprint-retrospective` (separate skill) owns it.

---

## 12. Reconcile active-context cursor

On the all-pass path — after harvest (§9) and cleanup (§10), after the §11 sprint-close branch, and BEFORE the §14 final handoff — reconcile the live `05-active-context.md` so a fresh session (or a `/handoff` consumer) reading it top-down sees the just-closed slice as closed and the correct next cursor. `05` is a LIVE, dev-authored file (never auto-regenerated): this is a *targeted, surfaced* edit, never a templated regen.

### 12.1 Compute the cursor target (field-read, mechanical)

Reuse the same shared lookup §11 uses (`sd roadmap_next_slice` / `sd roadmap_next_sprint`) — never paraphrase a slice name or grep ROADMAP headings:

```bash
next_vs_id="$(sd roadmap_next_slice "$vs_id")"   # empty ⇒ final slice of the sprint
if [[ -z "$next_vs_id" ]]; then
  next_sprint_id="$(sd roadmap_next_sprint "$sprint_id")"  # empty ⇒ final sprint in roadmap
else
  next_name="$(sd roadmap_slice_field "$next_vs_id" name)" # human label, field-read (schema key is `name`)
fi
active_context="$(sd state_active_context_path)"
```

### 12.2 Surface the proposed edit and wait

Read the `## Current focus` and `## Next up` blocks of `$active_context`. Surface BOTH the current text and the proposed replacement, then wait for the user to confirm / edit / skip (per §16 surface-and-wait discipline — never auto-apply):

- **Current focus** — flip the closed slice's in-flight marker to closed. Show the change, e.g.:

  > **Current focus** (proposed):
  > - was: `**Sprint <sprint_id> · <vs_id> — IN FLIGHT (…)**`
  > - now: `**<vs_id> — CLOSED (<merge-ref>)**` · round log below retained

  (`<merge-ref>` = the slice→sprint, or slice→main, merge reference — a merge-commit SHA or PR number, e.g. `a1b2c3d` or `PR #142`.) Preserve the slice's round detail verbatim as historical record — flip only the status header.

- **Next up** — set it from the field-read target:
  - Non-final slice: `Next: /orchestrate <next_vs_id> — <next_name>`.
  - Final slice of the sprint: point at sprint-close → next sprint, e.g. `Sprint <sprint_id> complete — next: sprint <next_sprint_id>` (or, when `next_sprint_id` is empty, `Sprint <sprint_id> complete — no next sprint in the published roadmap`).

### 12.3 Apply (prose only)

On the user's confirmation (with any edits folded in), apply the targeted edit to the two prose blocks only. Do NOT:
- regenerate `05-active-context.md` from any template;
- touch the structured `<!-- sd:cursor:start -->…<!-- sd:cursor:end -->` JSON block (that belongs to `planning-vertical-slice`, which sets the cursor when the next slice is actually planned);
- delete or rewrite the closed slice's round log;
- write any spec-derived file.

If the user skips, leave `05` untouched and say so; the ceremony still proceeds to the final handoff.

---

## 13. Invocation (natural language or `/orchestrate` close phase)

The closing ceremony has **no dedicated slash command** — it is invoked by a natural-language trigger ("close VS-N.M.K", "slice close", "wrap up the slice") or from `/orchestrate`'s close phase (the sprint driver closes each slice). Extract the VS-id (the full 3-part id `VS-<phase>.<sprint>.<slice>`) from the trigger; never reference `$1`/`$2` (`feedback_slash_command_dollar_n_bug`).

**Review-gate override:** when the close runs inside `/orchestrate`, any per-invocation `--gate` override that `/orchestrate` parsed (see `planning-vertical-slice` §13) is already in context as `gate_override`, and §7.0 passes it through as `sd review_gate_resolve --gate "$gate_override"`. A standalone natural-language close carries no override, so the manifest `.review_gate` applies.

Unknown or missing VS-id → one-line error + stop:

> Closing requires a VS-id. Example: close VS-1.1.1

---

## 14. Final handoff

After §10 cleanup, the §11 sprint-close branch (if applicable), and the §12 active-context reconcile, emit the closing message:

> **VS-`<vs_id>` closed.** Demo verification: `<N>` `auto:` + `<M>` `user:` steps all passing. Architect-critic: `<finding-count or "skipped">`. Memory bank harvest: `<X>` items promoted (`<R>` from `[report]`, `<H>` from `[handoff]`), `<L>` left in handoff. Worktrees + branches removed. Retrospective at `${slice_root}/retrospective.md`.

Eval S1 / S3 / S4 assert the target subagent's final assistant message indicates the slice is closed — judge accepts `VS-1.1.1 closed`, `VS-1.1.1 close ceremony complete`, or equivalent. Silent termination fails the assertion.

---

## 15. Anti-patterns (do not do these)

- **Running auto-demo commands inside a worktree.** `cd "$canonical"` is binding (eval S1 rejects any `cd <worktree>` prefix) — a worktree branch may be at a pre-merge HEAD → false-greens.
- **Continuing past the first auto-demo failure.** Halt immediately (eval S2: exactly one Bash invocation on first-fail); preserve worktrees; surface the 3-option recovery menu.
- **Removing worktrees before harvest completes** (§11 M2). Eval S1 + S4 fail any `git worktree remove` / `git branch -D work-*` that precedes the `retrospective.md` Write or any harvest Read.
- **Removing worktrees on an auto-demo halt.** Eval S2: none may appear — worktrees stay for inspection; the user picks the menu option and the ceremony re-runs from §5.
- **Paraphrasing the source-tag tokens.** Literal `[report]` / `[handoff]` square brackets are load-bearing (eval S1 + S4) — `(report)`, `<handoff>`, `[Report]` all fail.
- **Mis-labeling the `source:` field** in the provenance trailer — `source: report` for `report.md` origin, `source: handoff` for a handoff; swapping fails eval S4.
- **Sweeping sprint-scoped handoffs.** The glob is slice-scoped `${handoffs_dir}/${vs_slug}-*.md` (`vs_slug="vs-${vs_id#VS-}"`); never `vs-${vs_id}-*.md` (would be `vs-VS-1.1.1-*.md`). A `sprint-3-context-bloat-*.md` Read fails eval S1 + S4.
- **Silent skip OR blocking error when architect-critic is absent.** Emit the one §7.3 warning naming `architect-critic` / `adversarial review`; never prompt to install; never retry the probe (eval S3).
- **Invoking architect-critic via Task tool or `inbox/`/`outbox/` file IPC** (eval S1). Only the in-conversation `Skill(architect-critic:critiquing-spec)` is correct; never the legacy `Skill(architect-critic:critique)` name.
- **Authoring `retrospective.md` BEFORE the architect-critic moment** (eval S1: Write after the invocation; section 3 captures findings) **or AFTER harvest applies items** (section 4 is harvest's in-place destination — Write before §9 Reads).
- **Auto-selecting a recovery menu option.** It is a user decision boundary; eval S2 asserts no `Task` on the halt turn (option 3 is user-gated).
- **Reading manifest fields via raw `jq`.** Route all reads through `sd_manifest_get` / `sd_manifest_resolve`.
- **At the §12 reconcile:** regenerating `05-active-context.md` from a template (it is LIVE, dev-authored — targeted edit to `## Current focus` / `## Next up` only); deleting the closed slice's round log (flip only the status header, #66 AC); paraphrasing the "Next up" slice instead of field-reading via `sd roadmap_next_slice` / `sd roadmap_slice_field … name` (#66 AC); writing the `<!-- sd:cursor:start/end -->` block or any spec-derived file (cursor belongs to `planning-vertical-slice`); applying without surfacing-and-waiting.
- **Letting this body exceed 500 lines.** Hard cap per superpowers:writing-skills Pass D guidance; move reference-grade detail to `references/*.md`.

---

## 16. Notes on tool boundaries

- **You** make every judgment call: phrasing the recovery menu, categorizing each harvest candidate, surfacing source-tagged candidates with enough context, phrasing the closing handoff.
- **Bash helpers** (`lib/manifest.sh`, `lib/render.sh`, `lib/compose.sh`, `lib/worktree.sh`, `lib/harvest.sh`) handle pure I/O: manifest reads, template substitution, filesystem probes, worktree teardown, `sd_harvest_apply` (write + idempotency + reroute) and `sd_harvest_lint_length`. Demo-line parsing is inline (split on ` → expected: `); content-expectation evaluation is agent-judged.
- **`architect-critic:critiquing-spec`** owns the close-depth review (invoked once between Layer 2 and §8); **`writing-sprint-retrospective`** owns the sprint retrospective (not this skill); **`scaffold-onboard:authoring-vertical-slice-demo`** owns demo-criteria authoring (recovery option 1 hands off to it).
- **The user** is the final authority on every demo result, critic challenge, harvest decision, and menu choice. Never auto-advance past a decision boundary; never auto-cleanup; never auto-select a menu option.

When in doubt, prefer surfacing-and-waiting. The ceremony's value is the deterministic ordering — demos before critic, critic before retrospective, retrospective before harvest, harvest before cleanup, cleanup before the §12 reconcile — with the §11 M2 marker (worktrees survive until harvest completes) the load-bearing discipline.
