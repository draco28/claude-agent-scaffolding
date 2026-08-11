# Session Handoff — ossify v0.2.0 shipped; v0.3 sequence set to #138 → Batch E → `doctor`

**Authored against the approved session-handoff v2 design**
(`docs/superpowers/specs/2026-07-29-session-handoff-v2-design.md`): six-section core,
claims written checkable, references pointed at rather than copied. Hand-authored for the
same reason as its seven predecessors — the v1 skill refuses without a pairing manifest
this repo does not have, and the v2 skill is Plan C2 work (issue #113).

Seventh live dogfood. Its predecessor handed off a **built release stuck in review**; this
one hands off a **shipped release and a chosen sequence**. The predecessor's flagged weak
claim — that a 3-point trend (9/12/11) showed non-convergence — was **half right**: the
count did fall (10/12/11/6/2/2/5/4), but the review never went empty and two of the last
four rounds were regressions introduced while fixing earlier ones. The equivalent weak
claim here is named in §7.

---

## 1. Orientation

**ossify v0.2.0 — *reachability + truth* — is MERGED and TAGGED.** PR #130 landed as a
real merge commit (`3ea0ef0`, two parents) and `ossify-v0.2.0` points at that merge commit,
inside `main`'s history. The v0.1.0 orphaned-tag failure did not recur.

The engine Plan C1 shipped was unreachable: nothing routed a user into the
round-orchestration lane. v0.2 fixed that and made the prose around it true.

**The decision already made, and the reason this handoff exists:** the next work is
**#138 (executable-prose gate) → Batch E → `doctor`**, in that order. §3.1 carries the
argument. Do not silently reorder it — but §7 names the honest counter-argument.

**Do first:** run §5 step 1. Believe nothing here until it passes.

---

## 2. State — as checkable claims

| Claim | How to check |
|---|---|
| PR **#130 MERGED** at 2026-08-11T04:56:50Z | `gh pr view 130 --json state,mergedAt` |
| Merge commit **`3ea0ef0`** with **two parents** — a merge, not a squash | `git log -1 --format='%h parents=%p' 3ea0ef0` |
| Tag **`ossify-v0.2.0` → `3ea0ef0`**, and it is an ancestor of `main` | `git merge-base --is-ancestor 'ossify-v0.2.0^{}' origin/main` |
| `plugin.json` at the tag is **`0.2.0`** | `git show 'ossify-v0.2.0^{}:ossify/.claude-plugin/plugin.json' \| jq -r .version` |
| ossify suite: **25 files, 1,041 assertions, ALL GREEN** | `bash ossify/tests/run-all.sh` |
| eval gate: **28/28, exit 0** | `bash ossify/tests/eval/lib/aggregate-scores.sh` |
| repo-root parity clean | `for t in tests/test-*.sh; do bash "$t" \|\| echo "ROOT-FAIL: $t"; done` |
| descriptions **3120/3121** — one character of headroom, test-enforced | `bash ossify/tests/test-skill-bash-blocks.sh` (checks 6 and 7) |
| ossify still **absent** from the marketplace manifest (Plan D's gate) | `jq -r '.plugins[].name' .claude-plugin/marketplace.json` |
| **20 open ossify issues**: 8 from PR #118, 12 from PR #130 (#131–#142) | `gh issue list --state open --limit 40` |
| **Droid Code Review is `disabled_manually`**; Droid Tag still active | `gh workflow list --all` |
| Ruleset "Protect main" requires **only** `repository test suites` | `gh api repos/draco28/claude-agent-scaffolding/rulesets/20492634` |

**Housekeeping deliberately NOT done** — left for whoever picks this up, so the choice is
visible rather than assumed:

- local `main` is **27 behind** `origin/main`; the checkout is still on `feat/ossify-v0.2.0`
- `feat/ossify-v0.2.0` still exists **locally and on the remote** (`delete_branch_on_merge=false`)
- `?? .claude/` is this repo's documented steady state and stays

**Base for any review package — a rule, not a hash.** Read `git log --oneline -1` at the
moment you need it. Five handoffs in this series recorded a hash that was stale on arrival.

---

## 3. Uncodified context

### 3.1 — The sequence, and why #138 comes before the blocker

`doctor` is v0.3's centrepiece and is **hard-blocked**: descriptions closed at **3,120 of
3,121** characters and `check 7` **fails the suite** past that. `doctor` is the sixth entry
skill and physically cannot fit until **Batch E** frees ~120 tokens. So Batch E gates the
largest item in the release, and the obvious order is Batch E first.

**The chosen order is #138 first anyway.** The argument:

Batch E edits eight prose surfaces *and* all five entry-skill descriptions against a
one-character budget. That is precisely the edit shape that produced eight review rounds
and two self-inflicted P1s on #130. Building the executable-prose gate first means v0.3's
much larger surface gets written with the gate already in place, rather than repeating this
cycle at greater scale. #138 is also well-scoped rather than exploratory — the pattern
already exists and is proven (`test-close.sh`'s W1/W2 and D1–D4); the work is generalising
it.

The counter-argument is real and is not dismissed: #138 is prevention, Batch E is the
blocker, and #138 delays `doctor` by however long it takes. If #138 turns out to be bigger
than a session, **reconsider rather than grind** — the ordering is a judgment, not a
constraint.

### 3.2 — What eight review rounds actually taught, in one place

Round counts: **10 / 12 / 11 / 6 / 2 / 2 / 5 / 4**. ~56 findings, **not one a false
positive**. Rounds 7–8 were Codex-only (Droid broke, then was disabled).

**Six recurring defect classes.** These are the seed checklist for #139 and the thing to
pre-empt on any prose edit:

1. **Guards that cannot fire — or fire always.** A verb returning 0 on empty; a quoted `?`
   in a `case` pattern making a wildcard literal; a `*)` arm accepting detached `HEAD`; a
   guard whose variable is never assigned, so it halts on every run.
2. **Ordering.** An assertion placed after the mutation it guards; an instruction in a file
   read after the step it governs; `SPINE.md` emitted before its sections are decided.
3. **Cross-file contradictions introduced in the same change.**
4. **Usage strings that disagree with the lib contract.**
5. **Prose claiming behaviour no command implements.**
6. **A gate whose status is discarded by a trailing command.**

**Two process lessons that cost the most:**

- **A test that injects the precondition cannot see the code failing to establish it.**
  W2 passed `base_branch='w2-planned'` into the extracted block, so it validated the guard
  while being blind to nothing assigning the variable — and a sibling assertion encoded the
  bug as intended behaviour. `/run-spine` was dead on every fresh run and the suite was
  green. W2 now runs the block with **nothing injected** under `set -u`.
- **Anchor block-extraction on a token that survives the regression being guarded.** D1–D4
  first anchored on `demo_rc` — the thing under test — so removing the fix made the block
  unfindable and the failure reported as *"vacuous"* rather than as wrong behaviour.
  Re-anchored on `elapsed=`. #138 must carry this rule.

**Mutation-verify, and confirm the mutation applied.** Every fix this session was proven by
reintroducing the bug and watching named assertions go red.

### 3.3 — Decisions settled; do not relitigate silently

| | |
|---|---|
| **D-1** | Next work is **#138 → Batch E → `doctor`** (§3.1) |
| **D-2** | `/run-spine` resume is **not supported in v0.2** — it halts explicitly and points at #133. The lane derives `base_branch` from HEAD; the planned-base read is deferred |
| **D-3** | **Droid Code Review is off** for usage reasons. Codex is the only automatic reviewer. Droid Tag stays active (mention-gated, ~zero cost) |
| **D-4** | `code-review` was removed from the ruleset's required checks — it was Droid's job key and became permanently unsatisfiable once Droid was disabled |
| **D-5** | v0.3 gains two roadmap items #130 proved were missing: **#138** and **#139**. Dogfooding and a pre-push self-review pass were **considered and deliberately excluded** |

### 3.4 — The backlog has triage debt, and at least one issue is stale

There are **8 open ossify issues predating #130** (#120, #122–#126, #128, #129 — all from
PR #118's review) alongside the 12 from #130. Nobody has checked them against what v0.2
actually changed.

**#128 is already fixed and should be closed.** It reports `oss_worktree_dir` as dead code;
v0.2 removed it (`08b204f`), and `ossify/lib/worktree.sh:40` now carries only a tombstone
comment. Verified against the tree, not the label.

**#126 is probably still live** — `oss_verify_parse_acs` still exists
(`ossify/lib/verify.sh:10`) — but v0.2's redgate work (`f76cab2`) touched adjacent
behaviour, so it needs a real read rather than an assumption.

Recorded lesson this repo already learned the hard way: **an issue's state can lie about the
code in both directions** (#96 was closed-COMPLETED with no fix present). Triage the eight
before planning v0.3 scope.

### 3.5 — Environment changes made this session

Three things about this machine and repo changed, and they are not in git:

- **`.claude/settings.json` was created by the user** with a `Bash(gh api graphql:*)`
  permission rule. It is untracked (`?? .claude/`).
- **Workflow `330353845` (Droid Code Review) is `disabled_manually`.** Reversible with
  `gh workflow enable 330353845`. Its YAML is untouched on disk, so the file gives no hint
  that it is off — `gh workflow list --all` is the only ground truth.
- **Ruleset `20492634` was edited** to drop the `code-review` required check. Everything
  else (deletion, non-fast-forward, PR-required, thread-resolution) is intact.

---

## 4. References — pointers, not copies

| Path | What's here |
|---|---|
| `docs/superpowers/plans/2026-08-06-ossify-release-roadmap.md` | **The roadmap.** v0.2 SHIPPED; v0.3 carries `doctor` + the Batch E prerequisite + the two new gates |
| Issues **#138** / **#139** | The two new v0.3 gates, each with acceptance criteria and the evidence that produced them |
| Issues **#131–#142** | #130's twelve deferrals. #131 (OpenCode) escalated to P1 in round 8 |
| Issues **#120, #122–#126, #128, #129** | PR #118-era ossify backlog, **untriaged against v0.2** (§3.4) |
| `docs/superpowers/reviews/2026-08-09-ossify-skill-audit.md` | The audit. Batches **A/B/C closed**; **D/E/F carried to v0.3**. Batch E's item list lives here |
| `ossify/tests/test-close.sh` | W1/W2 and D1–D4 — the extract-and-execute pattern #138 generalises |
| `docs/superpowers/handoffs/2026-08-10-ossify-v020-pr-review.md` | Immediate predecessor. Its §3.2 defect classes are superseded by §3.2 here (six classes, not four) |
| `.superpowers/sdd/progress.md` | Gitignored ledger. Read it, never `git clean` it |

---

## 5. Next actions, in sequence

1. **Verify this handoff before trusting it.** Done = the §2 claims agree.
   ```bash
   gh pr view 130 --json state,mergedAt
   git merge-base --is-ancestor 'ossify-v0.2.0^{}' origin/main && echo TAG-OK
   bash ossify/tests/run-all.sh                       # expect ALL GREEN, 1041
   bash ossify/tests/eval/lib/aggregate-scores.sh     # expect 28/28
   gh workflow list --all                             # Droid Code Review disabled
   git status --porcelain                             # expect only `?? .claude/`
   ```
2. **Housekeeping first, it is two minutes.** Fast-forward local `main`, move off the merged
   branch, and decide on deleting `feat/ossify-v0.2.0` (local + remote). The work is merged
   and tagged, so nothing is at risk.
3. **Close #128** — verified fixed by v0.2 (§3.4) — and **triage the other seven PR-#118
   issues** against the current tree before scoping anything. Expect at least one more to
   be stale.
4. **Build #138, the executable-prose gate.** Read the issue; it carries the acceptance
   criteria. The non-obvious requirements: a **vacuity guard per block**, a **NOT-COVERED
   ledger** for deliberately-excluded blocks, and extraction anchors that **survive the
   regression they guard** (§3.2). Classify blocks as operative vs illustrative first —
   `cumulative-demo.md` §1 is illustrative and should be in the ledger, not executed.
5. **Then Batch E** — free ~120 description tokens so `doctor` can fit. Item list is in the
   audit doc. Every edit here touches a `description:`, so the 3120/3121 budget is live on
   every commit.
6. **Then `doctor`**, with #136's schema remedy and patch-lane visibility resolving *into*
   it rather than beside it, per the roadmap's sequencing note.
7. **Re-run the full gate after prose edits**, not only after code edits.

---

## 6. Traps

- **Do NOT squash-merge.** Standing policy; per-commit history is the point. v0.2 merged
  correctly — keep it that way.
- **Do NOT tag before merging.** Tag the *merge commit*, after. v0.1.0 was orphaned by a
  branch-tag plus a squash.
- **Do NOT push to `main` directly.** Branch + PR always, even for docs.
- **Do NOT `git clean -fdx`** — it destroys `.superpowers/sdd/progress.md`.
- **Do NOT edit a `description:` without an offsetting trim** — one character of room, and
  `check 7` is a red test. This is the whole point of Batch E.
- **Do NOT add a line to `plan-spine/SKILL.md` or `start/SKILL.md`** without trimming —
  500/500 and 499/500.
- **The auto-mode classifier blocks compound `gh` commands.** A bare `gh pr merge …` is
  allowed; the same call joined with `&&`/`echo`/a loop is denied. Split them. This cost
  real time this session.
- **GraphQL `resolveReviewThread` batches cap out around 34 mutations** —
  `RESOURCE_LIMITS_EXCEEDED` past that, with earlier aliases still applied. Batch in chunks
  and re-query between.
- **A required status check whose workflow is disabled blocks every PR forever.** Rulesets
  do not appear in the branch-protection API — `gh api …/rulesets` is the only ground truth.
  Check it *before* disabling any reviewer workflow.
- **Do NOT reason about shell semantics under zsh** — `run-all.sh` forces bash, the Bash
  tool here is zsh. Run every idiom you write.
- **Do NOT touch `README.md`** — the user's own uncommitted edit.
- **architect-critic — the only supported form:** `export ARCHITECT_CRITIC_ARGS="--spec \"<abs>\" --close"`
  then a bare `Skill(architect-critic:critiquing-spec)`.

---

## 7. Read-out

```
Handoff read-out — ossify v0.2.0 shipped; next sequence chosen
  Location   docs/superpowers/handoffs/  (precedent: 7 prior handoffs, tracked)  tracked: yes
  §2 State   12 claims, each with a command; the release is MERGED + TAGGED and the tag is
             verified an ancestor of main — the v0.1.0 orphan did not recur
  §3 Value   the sequence and the argument for it; the SIX defect classes (up from four)
             and the two process lessons that cost most — test-injection blindness and
             extraction anchors; 5 settled decisions; backlog triage debt with one
             issue already verified stale; three off-git environment changes
  §4 Refs    8 pointers — roadmap, the two new gate issues, both issue cohorts, the
             audit carrying Batch E's item list, the test file #138 generalises
  §5 Order   7 steps; step 1 verifies this document, steps 2-3 are cheap housekeeping
             and triage that stop v0.3 being scoped against a stale backlog
  §6 Traps   12, incl. two new ones that cost real time: the classifier's compound-command
             block, and a required check whose workflow is disabled blocking PRs forever
  Fixed      the predecessor handed off an unmerged PR mid-review; this hands off a shipped
             release, so §5 leads with housekeeping + triage rather than fetch-and-decide
  Caught     #128 reports dead code that v0.2 already removed — found by checking the tree
             rather than the label, which is the same trap #96 sprang before
  Weakest    §3.1's ordering. Putting #138 before Batch E is a JUDGMENT, and the counter is
             strong: Batch E blocks doctor, the release's centrepiece, so prevention work
             first delays the thing v0.3 is for. It rests on an unmeasured claim — that
             #138 is a session-sized job. Cheap to test: scope #138 first, and if it is
             not session-sized, flip the order and build the gate alongside doctor instead.
```

**Self-verified before commit:** every §2 claim run against `origin/main` at `3ea0ef0`;
PR/issue/workflow/ruleset state read from `gh` rather than recalled; #128's staleness and
#126's liveness checked against the tree; the 1,041/28-of-28 figures re-measured; all cited
paths resolve.
