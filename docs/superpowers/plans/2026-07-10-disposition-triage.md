# Disposition Triage (Standing Delegation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gates auto-apply their own predicate-clean recommendations with an audit digest and escalate only high-stakes items, killing the 380-repetition "proceed with your recommendation" treadmill (pulse360#15).

**Architecture:** Amend the recommendation-policy SoT in place (new Disposition-triage section + Rule 5 standing-delegation rewrite), re-copy to the three byte-identical plugin copies, then render triage on each surface: `critiquing-spec` gets a Step 8.0 triage pass before the (now escalated-only) rebuttal walk plus two new state fields; `grill-me` gets a Rule-4 self-answer extension plus a fourth exit-summary section; `planning-vertical-slice` gates auto-advance via one governing sentence in §3.4 (line-cap-safe). Everything is guarded by the existing parity test plus extended grep-anchor tests; only `lib/state.sh` is real code (TDD).

**Tech Stack:** Markdown skill bodies, bash 3.2 (BSD/macOS-portable), jq, repo-local test harnesses (`tests/*.sh`, per-plugin `tests/`), gh CLI.

**Spec:** `docs/superpowers/specs/2026-07-10-disposition-triage-design.md` (committed `3a78c69`).

## Global Constraints

- `scaffold-dev/skills/planning-vertical-slice/SKILL.md` has a HARD 500-line cap and currently sits at 490 lines — every edit there must be net ≤ +2 lines (rewrite lines in place; never add sections).
- The digest header literal `⚡ Auto-applied` is a cross-surface stability contract — spell it identically everywhere (tests + agent-ops grep for it).
- `critiquing-spec` Step 10 summary: existing field labels (`Adversaries used`, `Challenges`, `Concessions`, `Deferred`, `Candidates piled`, `Principles`, `Elapsed`) must stay verbatim with two-space indentation; new lines are additive-only.
- Never hand-edit a plugin policy copy — edit `docs/conventions/recommendation-policy.md`, then `cp` to the three copies (parity test enforces byte-identity).
- Slash-command bodies: never `$1`/`$2` positionals; args flow via the `$ARGUMENTS` → env-var bridge (`ARCHITECT_CRITIC_ARGS`, `SCAFFOLD_DEV_ARGS`).
- Bash: macOS-portable (BSD awk, bash 3.2). `bin/arc` runs under `set -euo pipefail` but tests source libs non-strict — guard any no-match `grep` with `|| true` in lib code.
- Plugin content changes require version bumps in `plugin.json` + BOTH marketplaces (`.claude-plugin/marketplace.json`, `.agents/plugins/marketplace.json`) or `/plugin update` won't surface them.
- Only `accept` and `defer` recommendations are auto-appliable; `rebut` always escalates. `--neutral` keeps its exact current meaning and transitively disables triage.
- Repo git remote: `draco28/claude-agent-scaffolding`. The agent does all git ops, but `gh pr merge` / push-to-main require explicit in-turn user authorization (Task 8).

---

### Task 1: Marketplace issue + feature branch

**Files:** none (GitHub + git only)

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-07-10-disposition-triage-design.md` (on main).
- Produces: `$ISSUE` (marketplace issue number) used in commit messages and the PR body; branch `feat/disposition-triage`.

- [ ] **Step 1: File the marketplace issue (the #93 pattern)**

```bash
cd /Users/draco/projects/claude-agent-scaffolding
gh issue create --repo draco28/claude-agent-scaffolding \
  --title "Disposition triage (standing delegation): gates auto-apply predicate-clean recommendations, escalate the rest" \
  --body "$(cat <<'EOF'
Successor to #93 (recommend-by-default). Design doc: docs/superpowers/specs/2026-07-10-disposition-triage-design.md (commit 3a78c69).

Upstream finding: pulseai-labs/pulse360#15 (agent-ops id `grill-recommendation-default`) — 380 hand-typed "proceed with your recommendation" turns across 55 sessions after #93 shipped.

Scope (per the design doc's locked decisions):
- Amend `docs/conventions/recommendation-policy.md` in place: disposition-triage rule, 5-criterion escalation predicate (UNGROUNDED / VISION-SCOPE / ONE-WAY DOOR / TOP SEVERITY / CONTESTED), Rule 5 standing-delegation rewrite, `⚡ Auto-applied` digest contract, `--walk`/`reopen` vocabulary. Re-copy to the 3 plugin copies.
- `architect-critic:critiquing-spec`: Step 8.0 triage before the (escalated-only) rebuttal walk; `walk_mode`; Step 10 summary + state.json gain `auto_applied_count`/`escalated_count`.
- `ai-mentor:grill-me`: Rule 4 self-answer extension; 4th exit-summary section "Self-answered (delegated)"; dependent chains + escalations stay one-question-per-turn.
- `scaffold-dev:planning-vertical-slice`: gates auto-advance on predicate-clean recommendations (§3.4 governing rule); slice-close handoff always pauses.
- Versions: ai-mentor v2.4.0, architect-critic v0.6.0, scaffold-dev v0.18.0.

Supersedes (explicitly, per design §6): v0.2 "sequential rebuttal" settlement (narrowed to escalated subset); eval S1 grill-offer semantics (auto-resolve with a visible digest line; --walk restores the explicit offer).

Regression AC (verbatim from pulse360#15): a fresh critique/grill session on a multi-item plan requires ZERO manual "proceed with your recommendation" repetitions.
EOF
)"
```

Expected: prints the new issue URL. Record the number as `$ISSUE`.

- [ ] **Step 2: Create the feature branch**

```bash
git -C /Users/draco/projects/claude-agent-scaffolding checkout -b feat/disposition-triage
```

Expected: `Switched to a new branch 'feat/disposition-triage'`.

---

### Task 2: Amend the policy SoT + re-copy + parity test

**Files:**
- Modify: `docs/conventions/recommendation-policy.md` (full rewrite below)
- Modify (via `cp`, never by hand): `ai-mentor/references/recommendation-policy.md`, `architect-critic/templates/recommendation-policy.md`, `scaffold-dev/skills/planning-vertical-slice/references/recommendation-policy.md`
- Test: `tests/test-recommendation-policy-parity.sh` (existing, unchanged)

**Interfaces:**
- Produces (contract strings later tasks and tests depend on): section heading `## Disposition triage (standing delegation)`; digest header literal `⚡ Auto-applied`; predicate names `UNGROUNDED`, `VISION/SCOPE-TOUCHING`, `ONE-WAY DOOR`, `TOP SEVERITY`, `CONTESTED`; vocabulary tokens `--walk`, `reopen <ids>`, `accept all except <ids>`.

- [ ] **Step 1: Verify parity is green before touching anything**

Run: `bash tests/test-recommendation-policy-parity.sh`
Expected: `Passed: 7  Failed: 0`.

- [ ] **Step 2: Replace the SoT content**

Overwrite `docs/conventions/recommendation-policy.md` with exactly:

````markdown
# Recommendation policy (recommend-by-default + disposition triage)

> **Single source of truth.** This file is authored once at the marketplace root
> (`docs/conventions/recommendation-policy.md`) and shipped as a **byte-identical
> copy** inside each plugin that adopts it (repo-root `docs/` does not ship on
> `/plugin install`, so each plugin carries its own copy). The repo-root parity
> test `tests/test-recommendation-policy-parity.sh` fails if any copy drifts.
> **Edit the root copy; never hand-edit a plugin copy** — re-copy instead.

## What this is

A cross-cutting interaction convention for every skill that **surfaces a decision
to the user** — a grill question, a council verdict, an audit challenge, an
orchestration gate. By default, each surfaced decision carries a firm, expert,
vision-aligned **recommendation**, so the user can respond with guidance in hand
rather than adjudicate cold. And by default the agent itself **dispositions the
low-stakes, source-grounded decisions** (disposition triage, below), so the
user's attention goes only to the decisions that genuinely need it.

This policy governs **how** a decision is presented and **who dispositions it**,
never **what** is asked or challenged. The skill's own logic decides what to
surface; this policy only adds that a grounded recommendation rides along with
it, and that predicate-clean recommendations are applied rather than
re-confirmed.

## The rule

1. **Default-on — one firm recommendation.** Every surfaced decision carries
   **exactly one** recommended option plus a **one-line rationale** — not an
   option dump, not a balanced menu with no lean. State it plainly:
   *"Recommended: &lt;option&gt; — &lt;one-line why&gt;."*

2. **Vision-grounded, with a citation.** When a project source-of-truth is
   reachable, ground the recommendation in it and **cite the source inline**
   (e.g. `MASTER-SPEC §4.2`, the onboarding digest, a memory-bank file). When no
   source-of-truth is reachable, give a general best-practice recommendation and
   **label it as such** — *"(general best practice — no project spec found)"*.
   **Never fabricate a citation.** A recommendation the user cannot trace is worse
   than none.

3. **Accept / rebut / defer.** Every surfaced recommendation offers three
   first-class dispositions:
   - **accept** — adopt the recommendation as-is.
   - **rebut** — push back; the skill engages the rebuttal (and, where it scores
     rebuttals, scores it) before the recommendation stands or yields.
   - **defer** — valid but not now; the decision is **tracked** for later (filed as
     an issue / recorded as deferred), never silently dropped.

   Under disposition triage (below), the agent itself applies `accept` and
   `defer` recommendations that clear the escalation predicate; a
   `rebut`-recommended item is contested by definition and always escalates.

4. **Explicit opt-out.** A `--neutral` flag, or a natural-language "no
   recommendations" / "just give me the options" request, **suppresses** all
   recommendations for that invocation: surfaces revert to neutral options and the
   user adjudicates cold. Opt-out is per-invocation, not sticky. Triage has its
   own opt-out — `--walk` / *"walk them"* (see the vocabulary below); `--neutral`
   disables triage transitively (with no recommendations there is nothing
   grounded to apply).

5. **The user is the final authority.** That authority is exercised two ways:
   **directly**, on every escalated decision; and by **standing delegation** on
   decisions that clear the escalation predicate — a delegation this policy
   documents, the digest makes auditable, and any single invocation can revoke
   (`--walk`). Escalated classes never auto-apply, and an explicit user
   direction always overrides. A recommendation is still a lean, not a decision;
   what changes is that the user has pre-decided, in this policy, who
   dispositions the low-stakes class.

## Disposition triage (standing delegation)

Post-#93 evidence (pulseai-labs/pulse360#15): ~90% of surfaced recommendations
were accepted verbatim — 380 hand-typed "proceed with your recommendation" turns
across 55 sessions. The rational fix is wholesale delegation of the class the
user always accepts, with the high-stakes class escalated. Triage is
**default-on** for every adopting surface.

**The triage rule.** Classify each surfaced decision against the escalation
predicate:

- **Clears it** → apply the recommended disposition **immediately** — no user
  turn spent. Only `accept` and `defer` are auto-appliable; an auto-applied
  `defer` stays **tracked** (filed issue / deferred list), never silently
  dropped.
- **Trips it** → **escalate**: walk it with the surface's full cadence
  (recommendation attached, accept / rebut / defer, rebuttal scoring where the
  surface has it).

**Escalation predicate — escalate when ANY holds:**

1. **UNGROUNDED** — the recommendation cannot cite a reachable source-of-truth
   (MASTER-SPEC §, memory-bank file, onboarding digest, referenced issue/PR). A
   "(general best practice)" lean never auto-applies.
2. **VISION/SCOPE-TOUCHING** — the finding challenges or would change the
   vision, the scope, or a previously locked/settled decision (as recorded in
   ADRs, memory-bank settlements, or locked-decision sections of specs and grill
   exit summaries), rather than operating within them.
3. **ONE-WAY DOOR** — hard to reverse: public contracts, schema/data
   migrations, deletions, pushes or PR-merges to the canonical repo. (Local
   worktree→branch merges are reversible and do not trip this.)
4. **TOP SEVERITY** — the surface's own top class (e.g. `premise`-severity
   challenges in critique; restart-class options at orchestrate gates).
5. **CONTESTED** — the recommended disposition is `rebut`, or two adversaries
   (host + external) disagree about the finding. Agent-vs-agent disagreement
   needs a human referee.

**Audit digest.** The same turn that auto-applies emits a compact digest — the
header literal `⚡ Auto-applied` is a **stability contract** (anchor tests and
the agent-ops regression watch grep for it):

```
⚡ Auto-applied K of N
<id> · <finding one-liner> · <accept|defer> · <citation>
...
```

`reopen <ids>` pulls any auto-applied item back into a full walk — honored while
the session lives (and, where the surface persists state, before its run record
is appended).

**Vocabulary (identical across adopting surfaces; opt-outs are per-invocation,
not sticky):**

| Phrase / flag | Effect |
| --- | --- |
| `--walk` / "walk them" | Full sequential walk; triage disabled, nothing auto-applied |
| `--neutral` / "no recommendations" | Unchanged meaning: no recommendations at all → triage transitively disabled |
| `reopen <ids>` | Pull auto-applied item(s) back into a full walk |
| `accept all` / `accept all except <ids>` | Explicit bulk responses on the **escalated** set |

## Why default-on

A neutral option dump pushes the whole adjudication cost onto the user every time.
A firm, cited recommendation lets them accept fast when they agree, and gives them
something concrete to push against when they don't — itself faster than reasoning
from a blank slate. Grounding the recommendation in the project's own
source-of-truth (rather than generic best practice) is what makes it trustworthy,
and the skills that adopt this policy already have that source-of-truth in context,
so the grounding is essentially free.

Triage extends the same logic to disposition: when a recommendation is grounded,
low-stakes, and uncontested, re-confirming it costs the user a turn and buys
nothing — the delegation is a decision the user already made, repeatedly and
explicitly. The digest keeps every delegated disposition auditable and reversible
(`reopen`), so trust is verifiable rather than assumed.

## How a skill adopts this policy

Each adopting skill's `SKILL.md` references this file and describes, in a few
lines, how the policy renders on **its** surface (a grill question, a verdict, a
challenge, a gate) and which source-of-truth it grounds against — plus how
triage renders there: what auto-apply means on that surface, where the digest
appears, and which class counts as TOP SEVERITY. The universal rule above does
not change per skill; only the rendering does.
````

- [ ] **Step 3: Re-copy to the three plugin copies**

```bash
cd /Users/draco/projects/claude-agent-scaffolding
cp docs/conventions/recommendation-policy.md ai-mentor/references/recommendation-policy.md
cp docs/conventions/recommendation-policy.md architect-critic/templates/recommendation-policy.md
cp docs/conventions/recommendation-policy.md scaffold-dev/skills/planning-vertical-slice/references/recommendation-policy.md
```

- [ ] **Step 4: Run the parity test**

Run: `bash tests/test-recommendation-policy-parity.sh`
Expected: `Passed: 7  Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add docs/conventions/recommendation-policy.md \
  ai-mentor/references/recommendation-policy.md \
  architect-critic/templates/recommendation-policy.md \
  scaffold-dev/skills/planning-vertical-slice/references/recommendation-policy.md
git commit -m "feat(policy): disposition triage — standing delegation, escalation predicate, digest contract (#$ISSUE)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `lib/state.sh` — `auto_applied_count` / `escalated_count` (TDD)

**Files:**
- Modify: `architect-critic/lib/state.sh:108-197` (`ac_state_append_run`)
- Test: `architect-critic/tests/unit/test-state.sh` (insert T7e3 after T7e2, i.e. after line 180, before the `T7f` block at line 182)

**Interfaces:**
- Consumes: existing `ac_state_append_run` flag parser + `ac_guarded_jq_write`.
- Produces: flags `--auto-applied-count <int>` and `--escalated-count <int>` (both optional, default `0`); `recent_runs[]` rows gain `auto_applied_count` + `escalated_count` fields on BOTH flag and positional forms. Task 4's Step 9 snippet uses these exact flag names.

- [ ] **Step 1: Write the failing test**

Insert into `architect-critic/tests/unit/test-state.sh` immediately after the T7e2 block (after the `assert_eq "first deferred challenge text stored" …` line):

```bash
echo "T7e3: ac_state_append_run stores disposition-triage counts"
"$TESTS_DIR/../bin/arc" state_append_run \
  --request-id "crit-triage-style" \
  --depth close \
  --adversaries "claude" \
  --challenge-count 9 \
  --concessions 7 \
  --auto-applied-count 6 \
  --escalated-count 3 \
  --skill-invoked critiquing-spec \
  --elapsed-ms 30000
triage_id="$(jq -r '.recent_runs[-1].request_id' "$state_file")"
assert_eq "triage request_id stored" "crit-triage-style" "$triage_id"
aac="$(jq '.recent_runs[-1].auto_applied_count' "$state_file")"
assert_eq "auto_applied_count stored" "6" "$aac"
esc="$(jq '.recent_runs[-1].escalated_count' "$state_file")"
assert_eq "escalated_count stored" "3" "$esc"
legacy_aac="$(jq '.recent_runs[0].auto_applied_count' "$state_file")"
assert_eq "auto_applied_count defaults to 0 when omitted" "0" "$legacy_aac"
legacy_esc="$(jq '.recent_runs[0].escalated_count' "$state_file")"
assert_eq "escalated_count defaults to 0 when omitted" "0" "$legacy_esc"
```

(`recent_runs[0]` at this point is T7e's `crit-flag-style` row, appended without the new flags — that's the defaults assertion.)

- [ ] **Step 2: Run test to verify it fails**

Run: `bash architect-critic/tests/unit/test-state.sh`
Expected: FAIL — `ac_state_append_run: unknown flag: --auto-applied-count` (rc=2 from the parser), T7e3 assertions red. Pre-existing T1–T7e2/T7f/T8 stay green.

- [ ] **Step 3: Implement the flags**

In `architect-critic/lib/state.sh`:

a. Line 110, extend the locals:

```bash
  local deferred_count="0" deferred_challenges_json="[]"
  local auto_applied_count="0" escalated_count="0"
```

b. In the flag `case` (after the `--deferred-challenges` entry, line 122), add:

```bash
        --auto-applied-count) [[ $# -ge 2 ]] || { ac_log_error "ac_state_append_run: --auto-applied-count requires a value"; return 2; }; auto_applied_count="$2"; shift 2 ;;
        --escalated-count) [[ $# -ge 2 ]] || { ac_log_error "ac_state_append_run: --escalated-count requires a value"; return 2; }; escalated_count="$2"; shift 2 ;;
```

c. In the `ac_guarded_jq_write` call, add two `--argjson` bindings after `--argjson dch "$deferred_challenges_json"`:

```bash
    --argjson aac "$auto_applied_count" \
    --argjson esc "$escalated_count" \
```

and extend the jq object after `"deferred_challenges": $dch,`:

```bash
       "auto_applied_count": $aac,
       "escalated_count": $esc,
```

d. Update the comment block above the function (line 105-107) to mention the two new optional flags defaulting to 0.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash architect-critic/tests/unit/test-state.sh`
Expected: PASS — all assertions green including the five new T7e3 ones.

- [ ] **Step 5: Run the neighboring state suite (regression)**

Run: `bash architect-critic/tests/unit/test-state-external-runs.sh`
Expected: PASS (external-runs path untouched).

- [ ] **Step 6: Commit**

```bash
git add architect-critic/lib/state.sh architect-critic/tests/unit/test-state.sh
git commit -m "feat(architect-critic): state_append_run gains auto-applied/escalated counts (#$ISSUE)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: `critiquing-spec` — Step 8.0 triage + walk mode + summary fields

**Files:**
- Modify: `architect-critic/skills/critiquing-spec/SKILL.md` (Step 3 ~line 111, Step 8 lines 356–409, Step 9 lines 415–443, Step 10 lines 470–497, boundaries note line 516)
- Modify: `architect-critic/skills/managing-async-critique/SKILL.md` (one sentence, anchored on ``force `neutral_mode=true` ``)
- Modify: `architect-critic/commands/critique.md` (argument-hint + flag doc)
- Test: `architect-critic/tests/unit/test-recommendation-policy.sh`

**Interfaces:**
- Consumes: policy section `## Disposition triage (standing delegation)` (Task 2); `arc state_append_run --auto-applied-count/--escalated-count` (Task 3).
- Produces: conversation-state names `walk_mode`, `AUTO_APPLIED_COUNT`, `ESCALATED_COUNT`; Step 10 summary lines labeled `Auto-applied` and `Escalated` (additive to the stability contract).

- [ ] **Step 1: Extend the anchor test (failing first)**

Append to `architect-critic/tests/unit/test-recommendation-policy.sh`, before `report_results`:

```bash
# Disposition triage (pulse360#15) — Step 8.0 triage + digest + walk opt-out wired.
assert_file_contains "$POLICY" "Disposition triage"
assert_file_contains "$POLICY" "⚡ Auto-applied"
assert_file_contains "$SKILL" "Step 8.0"
assert_file_contains "$SKILL" "walk_mode"
assert_file_contains "$SKILL" "⚡ Auto-applied"
assert_file_contains "$SKILL" "reopen"
assert_file_contains "$SKILL" "auto-applied-count"
assert_file_contains "$SKILL" "Auto-applied     :"
assert_file_contains "$CMD" "argument-hint:.*--walk"
assert_file_contains "$ASYNC_SKILL" "walk_mode"
```

Run: `bash architect-critic/tests/unit/test-recommendation-policy.sh`
Expected: FAIL on the `$SKILL`/`$CMD`/`$ASYNC_SKILL` asserts (the two `$POLICY` asserts already pass from Task 2).

- [ ] **Step 2: Add walk-mode detection (Step 3 region)**

In `architect-critic/skills/critiquing-spec/SKILL.md`, insert a new paragraph immediately after the existing **Neutral mode (#93)** paragraph (line ~111):

```markdown
**Walk mode (pulse360#15).** Set `walk_mode = true` if `--walk` is present in `$ARCHITECT_CRITIC_ARGS`, or the user's natural-language invocation matched *"walk them"* / *"walk them one at a time"* / *"no auto-accept"*. When `walk_mode=true`, Step 8.0 triage is skipped entirely — every challenge is escalated and walked sequentially (the #93 behavior). Default is `false`; per-invocation, not sticky. `--neutral` also disables triage transitively: with no recommendations there is nothing grounded to auto-apply.
```

- [ ] **Step 3: Insert Step 8.0 and re-scope the sequential walk**

In the Step 8 section, insert after the **Recommend-by-default (#93)** block (which ends `…presents each challenge neutrally.` at line 370) and before **Sequential mode (default).**:

````markdown
**Step 8.0 — Triage (disposition triage, pulse360#15).** Skip this step when `walk_mode=true` or `neutral_mode=true` — then every challenge is walked below. Otherwise, before walking anything, initialize `AUTO_APPLIED_COUNT=0` and `ESCALATED_COUNT=0`, then classify every challenge in the consolidated list against the escalation predicate in the policy's *Disposition triage* section (`${PLUGIN_DIR}/templates/recommendation-policy.md`): UNGROUNDED / VISION-SCOPE-TOUCHING / ONE-WAY DOOR / TOP SEVERITY (`premise` is this surface's top class) / CONTESTED (recommended disposition is `rebut`, or the two adversaries disagree on the finding).

- **Clears the predicate** → apply the recommended disposition now, incrementing `AUTO_APPLIED_COUNT`: `accept` → mark as concession; `defer` → append `{index,text,severity,rationale}` to `DEFERRED_CHALLENGES_JSON` and increment `DEFERRED_COUNT`.
- **Trips the predicate** → add to the escalated list, incrementing `ESCALATED_COUNT`.

Then emit the digest — the `⚡ Auto-applied` header is a stability contract (anchor tests + the agent-ops regression watch grep for it):

```
⚡ Auto-applied K of N
<index> · <challenge one-liner> · <accept|defer> · <citation>
...
Escalated: M challenge(s) — walking them now. (`reopen <ids>` pulls an auto-applied item back into the walk.)
```

Honor `reopen <ids>` at any point before Step 9's state append: reverse the item's auto-applied disposition (un-mark the concession, or pop the deferred entry and decrement `DEFERRED_COUNT`), decrement `AUTO_APPLIED_COUNT`, increment `ESCALATED_COUNT`, and walk it with the full cycle below.
````

Then change the sequential-mode opener:

- Old: `**Sequential mode (default).** For each challenge in the consolidated list, emit:`
- New: `**Sequential mode (the escalated subset).** For each escalated challenge (every challenge, when `walk_mode=true` or `neutral_mode=true`), emit:`

- [ ] **Step 4: Fold the alternative-batching escape hatch into triage**

Replace the second escape-hatch bullet (line 396):

- Old: `` `alternative`-severity challenges are **auto-batched at the end** by default. Don't walk them one-by-one alongside premise/gap challenges; collect them, present as a final group with a single ask. Alternatives are lower-stakes and the per-challenge ceremony is overkill.``
- New: `` `alternative`-severity challenges that **trip** the predicate are still **auto-batched at the end**: collect them, present as a final group with a single ask (most alternatives clear the predicate and were already auto-applied in Step 8.0; the per-challenge ceremony stays overkill for the rest).``

- [ ] **Step 5: Thread the counts through Step 9**

In the Step 9 `arc state_append_run` snippet (lines 418–428), add two flags after `--deferred-challenges "$DEFERRED_CHALLENGES_JSON" \`:

```bash
  --auto-applied-count "$AUTO_APPLIED_COUNT" \
  --escalated-count "$ESCALATED_COUNT" \
```

And append to the schema v3 field list (after the `concessions` bullet):

```markdown
- `auto_applied_count` — challenges auto-applied by Step 8.0 triage (0 under `--walk`/`--neutral`)
- `escalated_count` — challenges that tripped the predicate and were walked
```

Also extend the legacy-positional caveat sentence (line 430): the positional form records `auto_applied_count=0` / `escalated_count=0` as well.

- [ ] **Step 6: Extend the Step 10 summary (additive to the stability contract)**

In the Step 10 format block, insert after the `Concessions` line:

```
  Auto-applied     : <A> of <N> (disposition triage)
  Escalated        : <M> walked
```

And in the **Stability contract** token list, extend the field-label sentence to add `Auto-applied` and `Escalated` to the labels that MUST appear verbatim (two-space indentation, `:` separator). Existing labels stay untouched.

- [ ] **Step 7: Rewrite the final-authority boundary note**

Replace the last bullet of **Notes on tool boundaries** (line 516):

- Old: `- **The user** is the final authority. Your job is to surface candidate concerns (each with a recommended disposition per the recommendation policy, unless ` + "`--neutral`" + `); theirs is to accept, rebut, or defer. You never auto-promote without consent, and a recommendation never auto-advances past a decision boundary.`
- New: `- **The user** is the final authority — exercised directly on every escalated challenge, and by standing delegation (the policy's *Disposition triage* section) on challenges that clear the escalation predicate; the `⚡` digest keeps every delegated disposition auditable, and `reopen` / `--walk` revoke it. You never auto-promote without consent, and escalated classes never auto-apply.`

- [ ] **Step 8: Thread walk mode through async resume**

In `architect-critic/skills/managing-async-critique/SKILL.md`, locate the paragraph containing ``force `neutral_mode=true` `` and append this sentence to it:

```markdown
Likewise re-derive `walk_mode` from the persisted args: when the dispatched `$ARCHITECT_CRITIC_ARGS` carried `--walk`, the resumed unified rebuttal walks every consolidated challenge; otherwise it runs `critiquing-spec` Step 8.0 triage first (auto-apply predicate-clean dispositions, walk the escalated subset).
```

- [ ] **Step 9: Advertise `--walk` in the command wrapper**

In `architect-critic/commands/critique.md`:

- argument-hint → `"[path] [--close] [--neutral] [--walk] [--model NAME] [--principles PATH] [--scope project|user]"`
- Add to the Arguments list after the `--neutral` bullet:

```markdown
- `--walk` — walk every challenge sequentially; disables disposition triage (no auto-applied dispositions) for this invocation.
```

- [ ] **Step 10: Run the anchor test to verify it passes**

Run: `bash architect-critic/tests/unit/test-recommendation-policy.sh`
Expected: PASS — all asserts green, including the ten new ones.

- [ ] **Step 11: Commit**

```bash
git add architect-critic/skills/critiquing-spec/SKILL.md \
  architect-critic/skills/managing-async-critique/SKILL.md \
  architect-critic/commands/critique.md \
  architect-critic/tests/unit/test-recommendation-policy.sh
git commit -m "feat(architect-critic): Step 8.0 disposition triage — auto-apply clean challenges, walk the escalated subset (#$ISSUE)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: `grill-me` — Rule 4 self-answer extension + exit-summary section

**Files:**
- Modify: `ai-mentor/skills/grill-me/SKILL.md` (Rule 4 line 31, new subsection after Rules, exit summary line 61)
- Modify: `ai-mentor/commands/grill-me.md` (argument-hint + body sentence)
- Modify: `ai-mentor/tests/test-recommend-by-default.md` (two new fixtures)

**Interfaces:**
- Consumes: policy *Disposition triage* section via `${CLAUDE_PLUGIN_ROOT}/references/recommendation-policy.md` (copy updated in Task 2).
- Produces: exit-summary section name `Self-answered (delegated)` (referenced by the fixtures and by the design's audit-trail contract); digest header `⚡ Auto-applied` rendered at the top of the next question turn, never as a dedicated turn.

- [ ] **Step 1: Extend Rule 4**

Replace Rule 4 (line 31):

- Old: `4. **Explore before asking.** Verifiable facts get read/grepped, not asked. ✗ "Do you have a test framework?" → `Read pyproject.toml`. ✓ "Why did you pick X over Y?" — only the user knows.`
- New: `4. **Explore before asking — and self-answer what the SoT answers (disposition triage, pulse360#15).** Verifiable facts get read/grepped, not asked. ✗ "Do you have a test framework?" → `Read pyproject.toml`. ✓ "Why did you pick X over Y?" — only the user knows. Beyond raw facts: a question whose answer is **citable from the source-of-truth** AND clears the policy's escalation predicate is **never asked** — adopt your own lean as the working answer and record it (see *Triage rendering* below). Never self-answer a predicate-tripping question (ungrounded / vision-scope-touching / one-way door / top severity / contested) or any **dependent chain** where the next question hinges on the user's previous answer. Full predicate: `${CLAUDE_PLUGIN_ROOT}/references/recommendation-policy.md`, *Disposition triage*.`

- [ ] **Step 2: Add the Triage rendering subsection**

Insert a new section between **Rules** and **What to grill on**:

```markdown
## Triage rendering (pulse360#15)

Keep a running digest of Rule-4 self-answers. Surface accumulated lines at the top of your **next question turn** — never as a dedicated turn:

> ⚡ Auto-applied K of N
> <id> · <question one-liner> · <adopted answer> · <citation>

`reopen <id>` re-opens a self-answered branch as a live question. `--walk` / *"walk them"* disables self-answering for the invocation — every question is asked (the #93 behavior). `--neutral` disables it transitively (no leans to adopt). Under triage, Rule 1 (one question per turn) governs everything actually **asked**; self-answered items consume no turns.
```

- [ ] **Step 3: Extend the exit summary to four sections**

Replace the exit-summary sentence (line 61):

- Old: `On exit, post a summary with three sections: **Locked decisions** (choice + brief rationale per decision), **Open / deferred** (issue + why deferred), and **Worth re-checking later** (assumption + when/how to validate).`
- New: `On exit, post a summary with four sections: **Locked decisions** (choice + brief rationale per decision), **Self-answered (delegated)** (question + adopted answer + citation per disposition-triage item — the audit record; omit the section when empty), **Open / deferred** (issue + why deferred), and **Worth re-checking later** (assumption + when/how to validate).`

- [ ] **Step 4: Update the command wrapper**

In `ai-mentor/commands/grill-me.md`:

- argument-hint → `"[plan or design to grill] [--neutral] [--walk]"`
- In the body sentence, after `…suppresses them.` append: `` `--walk` (or "walk them") disables disposition triage — every question is asked, nothing self-answered.``

- [ ] **Step 5: Add behavioral fixtures**

Append to `ai-mentor/tests/test-recommend-by-default.md` (after the last fixture, keeping the table format used by R1–R5), and bump the fixtures count in the `## Fixtures (5 total)` heading to `(7 total)`:

```markdown
### R6 — grill-me self-answers a SoT-answerable question (disposition triage)

| Fixture field | Value |
|---|---|
| Setup | A repo with a MASTER-SPEC/memory-bank whose docs directly answer at least one obvious grill branch |
| Trigger | `grill me on <plan covered by the spec>` |
| Expected shape | The doc-answerable, low-stakes branch is never asked; a `⚡ Auto-applied K of N` digest rides at the top of the next question turn (question · adopted answer · citation); the exit summary contains a **Self-answered (delegated)** section listing it |
| Expected markers | `⚡ Auto-applied` header; citation per self-answered line; escalated/high-stakes questions still asked one per turn |
| Anti-pattern (FAIL) | Asking a question whose answer is verbatim in the spec, or self-answering a vision-touching / one-way-door / dependent-chain question |
| Status | RED (target: GREEN on this tree) |

### R7 — `--walk` restores ask-everything

| Fixture field | Value |
|---|---|
| Setup | Same repo as R6 |
| Trigger | `/grill-me <same plan> --walk` (or "grill me … — walk them") |
| Expected shape | No self-answers, no digest; every question asked one per turn with a recommendation attached (#93 behavior) |
| Expected markers | Zero `⚡ Auto-applied` occurrences in the session |
| Anti-pattern (FAIL) | Any auto-applied disposition under `--walk` |
| Status | RED (target: GREEN on this tree) |
```

- [ ] **Step 6: Run the ai-mentor lint**

Run: `bash ai-mentor/tests/test-frontmatter-lint.sh`
Expected: PASS (frontmatter untouched; body-only edits).

- [ ] **Step 7: Commit**

```bash
git add ai-mentor/skills/grill-me/SKILL.md ai-mentor/commands/grill-me.md \
  ai-mentor/tests/test-recommend-by-default.md
git commit -m "feat(ai-mentor): grill-me self-answers SoT-answerable questions — Rule 4 triage extension (#$ISSUE)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: `planning-vertical-slice` — gates auto-advance (line-cap-safe)

**Files:**
- Modify: `scaffold-dev/skills/planning-vertical-slice/SKILL.md` (§3.4 line 137, §8.7 lines 417+421, §13 line 463, §14 line 476, §15 line 488 — all in-place line rewrites, net ≤ +2 lines)
- Modify: `scaffold-dev/skills/planning-vertical-slice/references/orchestrate-args.md` (parser + carry-through)
- Modify: `scaffold-dev/commands/orchestrate.md` (argument-hint)
- Test: `scaffold-dev/tests/test-recommendation-policy.sh`

**Interfaces:**
- Consumes: policy *Disposition triage* section via `references/recommendation-policy.md` (Task 2); vocabulary `--walk`/`reopen`.
- Produces: `walk_mode` parsed from `$SCAFFOLD_DEV_ARGS`; §3.4 governing triage sentence that all five gates (§4/§5/§7.2/§8.5/§8.7) inherit — no per-gate prompt edits.

- [ ] **Step 1: Extend the anchor test (failing first)**

Append to `scaffold-dev/tests/test-recommendation-policy.sh`, before `sd_test_summary`:

```bash
# Disposition triage (pulse360#15) — gates auto-advance on predicate-clean recommendations.
assert_file_contains "$POLICY" "Disposition triage"
assert_file_contains "$POLICY" "⚡ Auto-applied"
assert_file_contains "$SKILL" "auto-advance"
assert_file_contains "$SKILL" "escalation predicate"
assert_file_contains "$SKILL" "⚡ Auto-applied"
assert_file_contains "$SKILL" "walk_mode"
assert_file_contains "$ARGS" "walk_mode"
assert_file_contains "$ARGS" "--walk"
assert_file_contains "$CMD" "--walk"
```

(The existing test already greps the leading-dash pattern `"--neutral"` through this helper, so `"--walk"` is safe as-is.)

Run: `bash scaffold-dev/tests/test-recommendation-policy.sh`
Expected: FAIL on the `$SKILL`/`$ARGS`/`$CMD` asserts.

- [ ] **Step 2: Rewrite §3.4's recommend-by-default bullet (line 137, one line → one line)**

Replace the whole line-137 bullet with:

```markdown
- **Recommend-by-default + disposition triage (#93, pulse360#15)** — having read the spec + memory bank above, attach **one firm recommendation** + a one-line *cited* rationale to every gate below (§4 decomposition, §5 rounds, §7.2 audit-skip, §8.5 fix-up, §8.7 round/slice-close), grounded in MASTER-SPEC/memory-bank (per `references/recommendation-policy.md`); the user may **accept / rebut / defer** — **accept** = take the recommended option, **rebut** = pick another option or push back, **defer** = proceed but record the flagged concern as tracked debt via `/defer` (`deferring-work-item`). **Triage (governs all five gates):** a gate whose recommendation clears the policy's escalation predicate **auto-advances** — apply the recommended option, emit one `⚡ Auto-applied` digest line (`gate · option · citation`), proceed without ending the turn; a predicate-tripping gate (ungrounded / vision-scope-touching / one-way door such as canonical push or PR-merge / restart-class / contested) pauses and surfaces its prompt as written below. `reopen <gate>` re-opens an auto-advanced gate while the slice conversation lives. `--walk` (§13, `walk_mode=true`) walks every gate; `--neutral` (§13) suppresses all gate recommendations (neutral menus, triage transitively disabled) — both are forwarded into every nested skill gate (`architect-critic` §7.2/§7.2a and `grill-me` §§4.1/6.3/8.5 receive them); escalated gates never auto-advance (§15).
```

- [ ] **Step 3: §8.7 — auto-advance rounds, always pause at slice close**

Line 417 item (1): change `set round status → complete in the VS README.` to `set round status → complete in the VS README (note any ⚡ auto-advanced gates this round).`

Line 421: replace

- Old: `"next round" → loop §8.1 for K+1; "close slice" → proceed to §10. Under `neutral_mode=true`, omit the `Recommended:` line from the prompt above.`
- New: `"next round" → loop §8.1 for K+1; "close slice" → proceed to §10. Under `neutral_mode=true`, omit the `Recommended:` line. **Triage (§3.4):** when rounds remain and the proceed-recommendation clears the predicate, auto-advance to round K+1 with a digest line; the final-round handoff **always pauses** — slice close is a deliberate user gate (§10).`

- [ ] **Step 4: §13 — parse `--walk` (line 463, in-place rewrite)**

In the line-463 paragraph: change `plus the optional `--backend` / `--gate` / `--neutral` overrides` to `plus the optional `--backend` / `--gate` / `--neutral` / `--walk` overrides`, and after `set `neutral_mode=true` when `--neutral` is present (suppresses every gate recommendation per §3.4)` insert `, set `walk_mode=true` when `--walk` is present (walks every gate — triage disabled per §3.4)`.

- [ ] **Step 5: §14 anti-pattern — digest-not-silence (line 476, one line → one line)**

Replace:

- Old: `- **Auto-invoking grill-me** — all three gates (§4.1 / §6.3 / §8.5) are explicit user-decidable offers (eval S1).`
- New: `- **Silently resolving a grill-me offer** — the three gates (§4.1 / §6.3 / §8.5) auto-resolve per §3.4 triage only WITH a visible `⚡` digest line; under `--walk` they are explicit user-decidable offers. Eval S1's target — silent skip or silent invocation — remains forbidden.`

- [ ] **Step 6: §15 final-authority bullet (line 488, one line → one line)**

Replace:

- Old: `- **The user** is the final authority — accepts/refines the decomposition + rounds (each gate carries a recommendation per §3.4 unless `--neutral`; a recommendation is a lean, not a decision), opts in/out of each grill-me, picks the failure-response option, gates slice close. Never auto-advance past a decision boundary.`
- New: `- **The user** is the final authority — exercised directly on every escalated gate (predicate-tripping per §3.4: vision-scope-touching decompositions, canonical merge boundaries, restart-class options, failure menus, slice close) and by standing delegation on gates that clear the predicate (auto-advanced with a `⚡` digest line; `reopen`/`--walk` revoke). Escalated gates never auto-advance.`

- [ ] **Step 7: Verify the line cap**

Run: `wc -l scaffold-dev/skills/planning-vertical-slice/SKILL.md`
Expected: ≤ 500 (rewrites are line-for-line; only §8.7 may add +1). If over: trim reference-grade wording from the §3.4 bullet (the predicate exemplars can shrink — the full predicate lives in the policy reference).

- [ ] **Step 8: orchestrate-args.md — parser + carry-through**

In `scaffold-dev/skills/planning-vertical-slice/references/orchestrate-args.md`:

a. Extend the intro sentence (line 5): `…and the optional per-invocation `--backend` / `--gate` / `--neutral` / `--walk` overrides:`

b. Near `neutral_mode=false` (line 11), add `walk_mode=false`.

c. In the parser `case`, after the `--neutral` entry, add:

```bash
    --walk)
      walk_mode=true
      shift
      ;;
```

(match the exact `shift` idiom the `--neutral` case uses — mirror it verbatim).

d. Extend the closing carry-through paragraph (line 56): after the `neutral_mode` sentence add: `When `walk_mode=true` (`--walk`), walk every gate sequentially — disposition triage disabled per §3.4 — and forward `--walk` into nested `architect-critic` / `grill-me` invocations alongside `--neutral`.`

- [ ] **Step 9: orchestrate.md argument-hint**

In `scaffold-dev/commands/orchestrate.md`: argument-hint → `"VS-N.M.K [--backend NAME] [--gate spec_close|both|off] [--neutral] [--walk]"`.

- [ ] **Step 10: Run the anchor test to verify it passes**

Run: `bash scaffold-dev/tests/test-recommendation-policy.sh`
Expected: PASS — all asserts green including the nine new ones.

- [ ] **Step 11: Commit**

```bash
git add scaffold-dev/skills/planning-vertical-slice/SKILL.md \
  scaffold-dev/skills/planning-vertical-slice/references/orchestrate-args.md \
  scaffold-dev/commands/orchestrate.md \
  scaffold-dev/tests/test-recommendation-policy.sh
git commit -m "feat(scaffold-dev): orchestrate gates auto-advance on predicate-clean recommendations (#$ISSUE)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Version bumps + changelogs + dual-publish parity

**Files:**
- Modify: `ai-mentor/.claude-plugin/plugin.json` (2.3.0 → 2.4.0), `architect-critic/.claude-plugin/plugin.json` (0.5.1 → 0.6.0), `scaffold-dev/.claude-plugin/plugin.json` (0.17.1 → 0.18.0)
- Modify: `.claude-plugin/marketplace.json` + `.agents/plugins/marketplace.json` (same three versions)
- Modify: `ai-mentor/CHANGELOG.md`, `architect-critic/CHANGELOG.md`, `scaffold-dev/CHANGELOG.md`

**Interfaces:**
- Consumes: version fields as they exist today (verify exact JSON paths at execution — read each file first).
- Produces: consistent versions across all five JSON files (guarded by `tests/test-codex-dual-publish.sh`).

- [ ] **Step 1: Bump the three plugin.json versions** (edit the `"version"` field in each).

- [ ] **Step 2: Mirror the bumps in BOTH marketplace manifests** (`.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json` — find each plugin's entry and update its version; also refresh any per-plugin description strings if they mention shipped feature counts).

- [ ] **Step 3: Changelog entries** — prepend to each plugin's CHANGELOG (match each file's existing heading style, verified at execution):

- ai-mentor `## 2.4.0 — 2026-07-10`: `Added — grill-me disposition triage (pulse360#15): SoT-answerable, predicate-clean questions are self-answered into a "Self-answered (delegated)" exit-summary section with a ⚡ Auto-applied digest; dependent chains + escalated questions stay one-question-per-turn; new --walk opt-out; recommendation-policy copy updated (triage + standing-delegation Rule 5).`
- architect-critic `## 0.6.0 — 2026-07-10`: `Added — critiquing-spec Step 8.0 disposition triage (pulse360#15): predicate-clean challenges auto-applied with a ⚡ Auto-applied digest, sequential rebuttal now walks the escalated subset; walk_mode (--walk); Step 10 summary + state.json gain auto_applied_count/escalated_count (state_append_run flags); async resume preserves walk mode; recommendation-policy copy updated.`
- scaffold-dev `## 0.18.0 — 2026-07-10`: `Added — orchestrate gates disposition triage (pulse360#15): predicate-clean gates auto-advance with a ⚡ Auto-applied digest line, escalated gates (canonical merges, restart-class, vision-touching, slice close) pause; --walk flag parsed + forwarded to nested skills; recommendation-policy copy updated.`

- [ ] **Step 4: Run the guards**

```bash
bash tests/test-codex-dual-publish.sh && bash tests/test-recommendation-policy-parity.sh
```

Expected: both end `Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add ai-mentor/.claude-plugin/plugin.json architect-critic/.claude-plugin/plugin.json \
  scaffold-dev/.claude-plugin/plugin.json .claude-plugin/marketplace.json \
  .agents/plugins/marketplace.json ai-mentor/CHANGELOG.md architect-critic/CHANGELOG.md \
  scaffold-dev/CHANGELOG.md
git commit -m "release: ai-mentor v2.4.0, architect-critic v0.6.0, scaffold-dev v0.18.0 — disposition triage (#$ISSUE)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Full suite → PR → Codex fix cycle → verified merge → closeout

**Files:** none new (CI/process)

**Interfaces:**
- Consumes: all prior commits on `feat/disposition-triage`; `$ISSUE`.
- Produces: merged PR, tags `ai-mentor-v2.4.0` / `architect-critic-v0.6.0` / `scaffold-dev-v0.18.0`, closed `$ISSUE`, pulse360#15 comment + finding marked built.

- [ ] **Step 1: Run the full test sweep for the touched plugins + repo-root guards**

```bash
cd /Users/draco/projects/claude-agent-scaffolding
for t in tests/test-*.sh architect-critic/tests/unit/test-*.sh scaffold-dev/tests/test-*.sh \
  ai-mentor/tests/test-*.sh; do
  [[ -f "$t" ]] || continue
  echo "== $t"; bash "$t" || echo "FAILED: $t"
done
```

Expected: zero `FAILED:` lines (`.md` fixture files are skipped by the `-f` glob only matching `.sh`). Distrust any "pre-existing failure" claim — verify against main if a suite is red.

- [ ] **Step 2: Push + open the PR**

```bash
git push -u origin feat/disposition-triage
gh pr create --repo draco28/claude-agent-scaffolding \
  --title "Disposition triage (standing delegation) — ai-mentor v2.4.0, architect-critic v0.6.0, scaffold-dev v0.18.0" \
  --body "$(cat <<EOF
Closes #$ISSUE

Design: docs/superpowers/specs/2026-07-10-disposition-triage-design.md. Upstream: pulseai-labs/pulse360#15.

- Policy SoT: disposition-triage section + Rule 5 standing delegation; parity copies re-copied.
- critiquing-spec: Step 8.0 triage, walk_mode, summary + state auto_applied/escalated counts.
- grill-me: Rule 4 self-answer extension, Self-answered (delegated) exit section, --walk.
- planning-vertical-slice: gates auto-advance via §3.4; slice close always pauses; --walk parsed + forwarded.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Let the 3-bot review stack run (Codex + CodeRabbit + Devin), then hand the fix cycle to the Codex companion** (per the standing workflow: Codex addresses all findings to "mergeable" and stops). After Codex's first round, deep-scan and batch-fix all similar/future-flaggable issues in ONE pass — never grind one-at-a-time.

- [ ] **Step 4: Independently verify before merge** — review the actual HEAD diff (not the peer's summary) and check unresolved review threads by GraphQL count:

```bash
gh api graphql -f query='query($owner:String!,$repo:String!,$pr:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$pr){reviewThreads(first:100){nodes{isResolved}}}}}' \
  -f owner=draco28 -f repo=claude-agent-scaffolding -F pr=<PR#> \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved|not)]|length'
```

Expected: `0`. Re-run the Task 8 Step 1 sweep on the post-fix HEAD.

- [ ] **Step 5: Merge + tag (requires explicit in-turn user authorization for the merge)**

```bash
gh pr merge <PR#> --repo draco28/claude-agent-scaffolding --squash --delete-branch
git checkout main && git pull
git tag ai-mentor-v2.4.0 && git tag architect-critic-v0.6.0 && git tag scaffold-dev-v0.18.0
git push origin ai-mentor-v2.4.0 architect-critic-v0.6.0 scaffold-dev-v0.18.0
```

- [ ] **Step 6: Closeout** — verify `$ISSUE` auto-closed (manually close if the keyword missed); comment on pulseai-labs/pulse360#15 linking the merged PR + tags; mark the finding built:

```bash
curl -X PATCH http://127.0.0.1:4141/api/findings/grill-recommendation-default \
  -H 'content-type: application/json' \
  -d '{"status":"built","note":"shipped: draco28/claude-agent-scaffolding PR <PR#> — ai-mentor v2.4.0 / architect-critic v0.6.0 / scaffold-dev v0.18.0"}'
```

(Skip gracefully if the dashboard isn't running; note it for later.)

- [ ] **Step 7: Dogfood regression AC (post-merge, fresh session)** — run one live `/critique` and one live grill on a real multi-item artifact: digest fires, zero manual "proceed with your recommendation" repetitions, exercise `--walk` and `reopen` once each. Record findings in the friction log.
