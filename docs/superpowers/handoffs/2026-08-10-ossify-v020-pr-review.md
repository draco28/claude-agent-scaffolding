# Session Handoff — ossify v0.2.0 built and open as PR #130, mid-review

**Authored against the approved session-handoff v2 design**
(`docs/superpowers/specs/2026-07-29-session-handoff-v2-design.md`): six-section core,
claims written checkable, references pointed at rather than copied. Hand-authored for the
same reason as its six predecessors — the v1 skill refuses without a pairing manifest this
repo does not have, and the v2 skill is Plan C2 work.

Sixth live dogfood. Its predecessor's read-out named the "only two majors remain" claim as
its weakest; that one was **right to flag** — re-running the reproductions found the Gate 2
major had not actually been resolved. The equivalent weak claim here is named in §7.

**This hands off a built release stuck in review, not a plan.** All 11 planned tasks are
done and pushed. Three bot-review rounds have produced **33 findings, every one real**, and
the round-over-round count is not falling the way a converging PR's should.

---

## 1. Orientation

ossify v0.2.0 — *reachability + truth* — is **built, green, and open as PR #130**. It is
**not merged and not tagged.**

The engine Plan C1 shipped was unreachable: nothing routed a user into the
round-orchestration lane. v0.2 fixes that and makes the prose around it true. Plan:
`docs/superpowers/plans/2026-08-09-ossify-v020.md`, 11 tasks, all closed.

**The open question this session could not settle: how many more review rounds to run.**
Round 3 was largely fallout from round 2's own fixes. See §3.1 — that is the decision
waiting for you, and it is a judgment call, not a lookup.

**Do first:** run §5 step 1. Believe nothing here until it passes.

---

## 2. State — as checkable claims

| Claim | How to check |
|---|---|
| On `feat/ossify-v0.2.0`, **20 commits ahead** of `origin/main`; nothing merged | `git rev-list --count origin/main..HEAD` |
| PR **#130 OPEN**, `mergeStateStatus=BLOCKED`, head `419e537` | `gh pr view 130 --json state,mergeStateStatus,headRefOid` |
| ossify suite: **25 files, 1,025 assertions, ALL GREEN** | `bash ossify/tests/run-all.sh` |
| eval gate: **28/28, exit 0** | `bash ossify/tests/eval/lib/aggregate-scores.sh` |
| repo-root parity clean, **including `test-opencode-live.sh`** | `for t in tests/test-*.sh; do bash "$t" \|\| echo "ROOT-FAIL: $t"; done` |
| `plugin.json` is **`0.2.0`** | `jq -r .version ossify/.claude-plugin/plugin.json` |
| ossify still **absent** from the marketplace manifest (Plan D's gate) | `jq -r '.plugins[].name' .claude-plugin/marketplace.json` |
| **33 inline review findings** to date across 3 rounds | `sd pr_review_comments 130 --repo-root "$PWD" \| jq length` |
| Issue **#131 OPEN** — the one deferral | `gh issue view 131` |
| Both budgets inside, and **test-enforced**: `plan-spine` 500/500 lines, descriptions **3120/3121** chars | `bash ossify/tests/test-skill-bash-blocks.sh` (checks 6 and 7) |

**Base for any review package — a rule, not a hash.** Read `git log --oneline -1` at the
moment you need it. Four handoffs in this series recorded a hash that was stale on arrival.

---

## 3. Uncodified context

### 3.1 — The review is not converging, and that is the live decision

| Round | Head | Findings | P1 | Character |
|---|---|---|---|---|
| 1 | `cafb173` | 9 | 7 | Real defects in the delivered work |
| 2 | `9f58cfb` | 12 | 3 | Partly new, partly round-1 fallout |
| 3 | `05e5f69` | 11 | 3 | **Mostly round-2 fallout** |

**Not one of the 33 was a false positive.** Both reviewers (`chatgpt-codex-connector`,
`factory-droid`) have been accurate throughout, and twice they independently found the same
defect — which is signal, not redundancy.

The problem is the *source* of rounds 2 and 3: **my fixes kept introducing the next round's
findings.** Round 3's three P1s were all consequences of round-2 edits. Recorded lesson
*"a correction is new code"* is exactly this, and it applied to me at a ~30% rate across
~30 fixes.

**Three options, and the third is the one nobody has costed:**

1. Keep running rounds. Every one has found real defects. But there is no evidence the
   next is empty, and I said that about round 3.
2. Merge and file the tail as v0.3 issues. Everything blocking is fixed; rounds 2-3 were
   P2/P3 prose refinement. This was my recommendation.
3. **Reassess scope.** v0.2 touched ~40 prose surfaces in one PR. The second-order-effect
   rate may be a property of the batch size, not of the work. Splitting the remaining
   polish out could converge faster than grinding this PR down.

Recorded lesson: PR #87 hit **nine** rounds and that was judged absurd. This is at three.

### 3.2 — Every finding has been mine, and they cluster into four classes

Useful because the next round can pre-empt them rather than rediscover them:

- **Guards that cannot fire.** A `verify_acs || halt` where the verb returns 0 on empty; a
  prefix-only expectation match; a wildcard branch arm that accepts detached `HEAD`. **When
  you write a guard, construct the input that should trip it and watch it trip.**
- **Ordering.** A canonical-only assertion placed *after* `worktree_add`; a
  "validate before the harvest" instruction placed in a file read *after* the harvest;
  `SPINE.md` emitted before the sections it must contain are decided.
- **Cross-file contradictions introduced in the same PR.** `spike-contract.md` said
  `NNNN-*.md` while `bones-registry.md` — same PR — mandated `adr-NNNN-`. Both bots caught it.
- **Usage strings vs lib contracts.** T3 generated 44 from comment headers; 4 were wrong
  wherever the wrapper's positional mapping differed from the lib's. Round 2 audited all 44
  — **that audit is done, the remaining 40 are correct.**

### 3.3 — Decisions settled this session; do not relitigate silently

| | |
|---|---|
| **D-1** | Bone ADRs → `<canonical>/docs/adr/adr-NNNN-kebab.md`, MADR-lite. The `adr-` prefix is load-bearing: it is what scaffold-dev/scaffold-onboard write |
| **D-2** | Feature-map rank/prune stay **conversational**; the map is append-only history |
| **D-3** | A patch **never** lands on a spine branch; allow-list the base branch by name |
| **D-4** | `oss release_dir` exposed, absolute, ai_workspace-rooted |
| **D-5** | **Mode C removed, not deferred** — ossify dispatches work to no other agent. This is why `code-review.md` runs its two axes *sequentially* rather than as the absorption spec's parallel sub-agents |

### 3.4 — The description budget is now a red test with 1 character of headroom

Descriptions closed at **3,120 of 3,121**. `check 7` (new this release) **fails the suite**
past that. Any edit touching a `description:` needs an offsetting trim in the same commit.

**This makes Batch E a hard prerequisite for v0.3's `doctor`** — the sixth entry skill's
description cannot physically fit. Batch E must free ~120 tokens first. The roadmap records
this; it is no longer advisory.

### 3.5 — #131 is the one deferral, and it is bigger than it reads

`/run-spine` is unreachable in OpenCode. The catalog alias is one line — and adding it turns
`test-opencode-live.sh` **red**, because `.opencode/lib/markdown.js` parses `allowed-tools`
as JSON while **all six** ossify commands use Claude Code's comma form. Registering any of
them throws at plugin init and takes `ossify-implementer-agent` down with it. Reproduced.
Claude Code — the supported path — is unaffected.

### 3.6 — The tests caught four of my own defects; trust them over your reading

`check 1` caught two unparseable bash blocks I wrote (an apostrophe in a placeholder; a bare
`<the failing command>`, which is shell redirection). `check 5` caught an orphaned reference
(a pointer from a sibling reference is not reachability — `close/SKILL.md` itself must name
it). `check 6` caught a 502-line overshoot. **Run the suite after prose edits, not just
after code edits.**

---

## 4. References — pointers, not copies

| Path | What's here |
|---|---|
| `docs/superpowers/plans/2026-08-09-ossify-v020.md` | **The plan.** 11 tasks, all closed. Carries the corrected scope, the 5 settled decisions, and the execution discipline |
| PR #130 + its `issue-comment` ledger | Round-1 dispositions in one table. Rounds 2-3 are in the commit messages |
| `docs/superpowers/plans/2026-08-06-ossify-release-roadmap.md` | v0.2 marked SHIPPED with the corrections it proved; v0.3's Batch-E prerequisite |
| `docs/superpowers/reviews/2026-08-09-ossify-skill-audit.md` | The audit. Batches **A/B/C closed**; **D/E/F carried to v0.3** |
| `docs/superpowers/reviews/2026-08-05-plan-c1-branch-review.md` | The C1 correctness review. **Fully closed** by v0.2 |
| `docs/superpowers/specs/2026-08-09-ossify-capability-gap-absorption.md` | 7 capability refs; **2 shipped** (debugging, code-review), 5 in v0.3 |
| `.superpowers/sdd/progress.md` | Gitignored ledger. Read it, never `git clean` it |
| `docs/superpowers/handoffs/2026-08-09-ossify-v01-to-v02.md` | Immediate predecessor. Its §6 traps still govern |

---

## 5. Next actions, in sequence

1. **Verify this handoff before trusting it.** Done = all ten §2 claims agree.
   ```bash
   git rev-parse --abbrev-ref HEAD && git rev-list --count origin/main..HEAD
   gh pr view 130 --json state,mergeStateStatus,headRefOid
   bash ossify/tests/run-all.sh                       # expect ALL GREEN, 1025
   bash ossify/tests/eval/lib/aggregate-scores.sh     # expect 28/28
   for t in tests/test-*.sh; do bash "$t" >/dev/null || echo "ROOT-FAIL: $t"; done
   git status --porcelain                             # expect only `?? .claude/`
   ```
2. **Fetch round 4 — both signals.** `sd pr_state 130` **and**
   `sd pr_review_comments 130`; the inline call is where the bots put findings. Anything
   newer than `419e537`'s reviews is round 4. If nothing new landed, that is itself the
   convergence signal §3.1 is waiting for.
3. **Settle §3.1 with the user before fixing anything.** More rounds, merge-and-defer, or
   split the remaining polish out. It is their call and it changes the work.
4. **If fixing: verify every finding against the tree first.** 33 for 33 have been real, so
   the prior is high — but the discipline is what makes the disposition honest, and it is
   what caught that the OpenCode alias was a much larger problem than it looked.
5. **Fix in ONE pass per round, and deep-scan the class** (`feedback_bot_review_batch_fix_one_pass`).
   Round 2's all-44 usage-string audit is the model: three were flagged, all 44 were checked.
6. **Re-run the full gate after prose edits**, not only after code edits (§3.6).
7. **Merge only on the user's explicit ack** — `--no-ff`, never squash — **then** tag
   `ossify-v0.2.0` on the merge commit and verify with
   `git merge-base --is-ancestor 'ossify-v0.2.0^{}' main`.

---

## 6. Traps

- **Do NOT squash-merge.** Standing policy as of 2026-08-09; the per-commit history is the
  point. `gh pr merge 130 --merge` (prefer `--no-ff`), never `--squash`.
- **Do NOT merge before tagging is possible** — tag *after* the merge, on the merge commit.
  v0.1.0 was orphaned by a branch-tag plus a squash.
- **Do NOT push to `main` directly.** Branch + PR always, even for docs.
- **Do NOT `git clean -fdx`** — it destroys `.superpowers/sdd/progress.md`.
- **Do NOT trust a reviewer's "0 unresolved" summary** — count by GraphQL. That summary has
  been wrong three times in this repo.
- **Do NOT edit a `description:` without an offsetting trim** (§3.4). One character of room.
- **Do NOT add a line to `plan-spine/SKILL.md` or `start/SKILL.md`** without trimming — 500/500
  and 499/500.
- **Do NOT register an ossify command in the OpenCode catalog** until #131 is fixed; it
  silently disables `ossify-implementer-agent`.
- **Do NOT reason about shell semantics under zsh** — `run-all.sh` forces bash, and the Bash
  tool here is zsh. Run every idiom you write.
- **Do NOT trust a `git status --porcelain` dirty-check to mean "unsafe"** — `?? .claude/` is
  this repo's documented steady state; `/work-pr`'s preflight trips on it.
- **Do NOT touch `README.md`** — the user's own uncommitted edit.
- **architect-critic — the only supported form:** `export ARCHITECT_CRITIC_ARGS="--spec \"<abs>\" --close"`
  then a bare `Skill(architect-critic:critiquing-spec)`.

---

## 7. Read-out

```
Handoff read-out — ossify v0.2.0 built, PR #130 open, mid-review
  Location   docs/superpowers/handoffs/  (precedent: 6 prior handoffs, tracked)  tracked: yes
  §2 State   10 claims, each with a command; the PR is OPEN + BLOCKED and the suite is
             1025/25-files GREEN — the block is reviewer signal, not a red gate
  §3 Value   the review is NOT converging (9/12/11, round 3 mostly round-2 fallout) and
             that decision is unmade; the four defect classes I kept re-introducing, so
             round 4 can pre-empt rather than rediscover; 5 settled decisions; the
             1-character description budget that is now a red test
  §4 Refs    8 pointers — plan, PR ledger, roadmap, audit, C1 review, capability spec
  §5 Order   7 steps; step 1 verifies this document, step 3 stops for a user decision
             BEFORE any fixing, because the answer changes the work
  §6 Traps   12, incl. no-squash, tag-after-merge, and the two SKILL.md line caps
  Fixed      predecessors handed off a plan or a shipped release; this hands off a
             built-but-unmerged PR, so §5 leads with fetch-and-decide rather than build
  Caught     the predecessor's flagged weak claim ("only two majors remain") turned out to
             be WRONG — re-running the four reproductions found the Gate 2 major only
             1/3 fixed. That flag earned its keep; keep flagging the weakest claim.
  Weakest    §3.1's "not converging" reads a 3-point trend (9/12/11) as a signal. Three
             points is not a trend, and round 3's volume is partly explained by round 2
             touching 12 surfaces rather than by any property of the work. Cheap to test:
             run round 4 and see. If it lands under ~5 findings with no P1, option 2
             (merge and defer) is clearly right and §3.1's framing was pessimistic.
```

**Self-verified before commit:** all six §5-step-1 commands run on `419e537`; PR/issue state
read from `gh` rather than recalled; the 33-finding count and the 3120/3121 budget
re-measured rather than carried; all 8 cited paths resolve.
