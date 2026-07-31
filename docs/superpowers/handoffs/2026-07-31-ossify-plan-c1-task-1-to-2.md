# Session Handoff — ossify Plan C1, Task 1 done → Task 2 next

**Authored against the approved session-handoff v2 design** (`docs/superpowers/specs/2026-07-29-session-handoff-v2-design.md`): six-section core, claims written checkable, references not duplicated. Hand-authored because the v2 *skill* is Plan C2 work and the v1 skill refuses without a pairing manifest, which this repo does not have — the exact friction that design exists to remove. Treat this document as a live dogfood of that design: if a section felt wrong to write, that is signal for C2.

---

## 1. Orientation

ossify is a skeleton-first lifecycle plugin replacing the scaffold-onboard + scaffold-dev pair. Plans A and B shipped its state engine and its three planning skills. **Plan C1 is the execution engine and both close ceremonies** — the half that makes *"the product still runs"* a checked fact rather than an assumption.

Plan C1 is written, adversarially reviewed, committed, and **Task 1 of 14 is done and approved**.

**Do first:** read §5 step 1. It is a five-command verification block. Run it before believing anything else in this document.

---

## 2. State — as checkable claims

Every claim carries a way to check it. If one fails, stop and reconcile before starting work.

| Claim | How to check |
|---|---|
| HEAD is `168f412`, branch `feat/ossify-core` | `git log --oneline -1` |
| 47 ahead of `main`, **0 behind**; branch deliberately unmerged | `git rev-list --left-right --count main...HEAD` |
| ossify suite: **17 files, ALL GREEN** | `bash ossify/tests/run-all.sh` |
| eval gate: **23/23, exit 0** (unchanged by C1 so far — C1 adds a 6th surface at Task 14, taking it to 28) | `bash ossify/tests/eval/lib/aggregate-scores.sh` |
| repo-root parity suite clean | `for t in tests/test-*.sh; do bash "$t" \|\| echo "ROOT-FAIL: $t"; done` |
| Working tree carries only pre-existing noise: ` M README.md` plus three untracked paths | `git status --porcelain` |
| Plan C1 is committed at `2a11a65`; Task 1 impl at `ff24d06`; Minor-fix at `168f412` | `git log --oneline 2a11a65..HEAD` |
| Task 1 review verdict: **APPROVED**, 0 Critical / 0 Important | `.superpowers/sdd/progress.md`, Task 1 block |

**Not verified, and flagged rather than asserted:** the `/doctor` skill-listing budget has not been re-measured since two entry skills were added to the *plan* (none are built yet, so nothing has moved). Task 14 owns the re-measure.

---

## 3. Uncodified context

What is true but written nowhere else.

**3.1 — The plan review found the engine had no producer, and that is the single most important thing to carry.** `plan-spine/SKILL.md:36-38` says verbatim *"This skill plans; it does not execute: worktree spin-up, implementer dispatch, verification, and merge belong to the execution engine (`work-item`)."* Plan C1 **is** that engine, and the plan as first drafted never built the lane — nothing authored a handoff, spawned a worktree, or dispatched the agent. The draft also cited a `plan-spine §8.3` that **does not exist**. Task 8 was added to fix this. When you reach Round 3, verify the lane is real, not just described.

**3.2 — Three CRITICALs were caught before any code existed**, by a 4-lens adversarial review of the plan itself (28 raised → 23 survived → 5 refuted, all folded before the plan was committed). The other two: work-item commits were being force-deleted at cleanup because nothing merged `work/<wi>` branches; and `lib/verify.sh` aborted the dispatcher on its normal path via an unguarded command substitution under `set -euo pipefail`, in a function whose entire job is running commands *expected* to fail. **Run the wiring lens ("who calls this?") against a plan, not just a diff** — it produced two of the three.

**3.3 — Four bugs were found in the plan's own code by testing it empirically before dispatch.** The worst: a zero-tests guard that returned "vacuous" for *every* input, which would have failed every `exit:0` demo line and made the cumulative demo — the one artifact spec §6.1 designates un-fakeable — unable to pass at all. The trap is that `lib/id.sh:4-6` and `lib/demo.sh:5,8` use the same `pipeline | { … return N; }` idiom **safely**, because there the pipeline is the function's last command. Copying it into a function with more to do is what breaks it.

**3.4 — That class is invisible under zsh.** zsh runs the last pipeline element in the parent shell; bash runs it in a subshell. My first test of 3.3 produced a false negative for exactly that reason. **Check shell semantics under `bash`, never under this session's zsh.** It is why `run-all.sh` forces `bash "$t"`.

**3.5 — Spec §8.1's capability catalog is a hypothesis, not a contract.** It marks `implementation-checking` as "Unchanged"; its documented entry point `sd_rules_apply` **does not exist**, three of four mcrule families have no evaluator, and the one that does returns no violation on a canonically-authored `banned_imports` rule. Recorded as plan decision D2. Two more §8.1 rows are wrong (`appending-changelog-entry`'s release-cut lane, `flipping-adr-status`'s "additive" claim). **Plan C2 lives almost entirely in §8.1 territory — verify every row against the code before planning it.**

**3.6 — Task 1's implementer found no new bugs in its brief.** That is a first for this series (the prior plan's briefs carried author bugs in 8 of 8 tasks). It is the plan review paying for itself, **not** the second-bug-catcher discipline decaying. Keep the "the brief's literal code may contain a bug" dispatch line exactly as it is.

**3.7 — The Task 1 reviewer closed a real gap I left.** The shipped migration fixture builds a v1 state with an *empty* journal, which is a lighter legacy simulation than a genuine upgrade. The reviewer hand-built a v1 state with real pre-existing journaled mutations, migrated, replayed — clean. No defect, but the test is weaker than the reviewer's probe. Worth strengthening if migrations recur.

**3.8 — `oss demo_run` gains a manifest requirement at Task 6**, where it had none. Three test files need a pairing-manifest fixture added and five need lib source-list updates. This is a behavioural change, not a refactor, and Task 6 says so explicitly — do not let a reviewer "fix" it back.

---

## 4. References — pointers, not copies

| Path | What's here |
|---|---|
| `docs/superpowers/plans/2026-07-29-ossify-plan-c1.md` | **The plan.** 14 tasks, 5 rounds, ~2000 lines. Global Constraints at top are binding and copied into every dispatch. Design decisions D1-D9 near the top explain why the naive reading of the spec is wrong in nine places |
| `.superpowers/sdd/progress.md` | **The ledger — ground truth.** Gitignored scratch: read it, never `git clean` it. Carries the two settled decisions, the plan-review outcome, the execution protocol, and Task 1's verified record |
| `docs/superpowers/specs/2026-07-11-poc-first-lifecycle-design.md` | Main spec. C1 scope = §6, §6.1, §6.2. §9.2 state-safety is BINDING |
| `docs/superpowers/specs/2026-07-12-public-private-boundary-design.md` | Companion. §4.2/§4.3 shape close; multi-repo itself is Plan D |
| `docs/superpowers/specs/2026-07-29-session-handoff-v2-design.md` | Approved; **Plan C2 absorbs it as scoped tasks — do not re-derive**. Issue #113 |
| `docs/superpowers/handoffs/2026-07-28-ossify-plan-b-to-c.md` | Predecessor handoff. Its §4 execution playbook and §5 gotchas still govern |
| `.superpowers/sdd/FINAL-REVIEW-2026-07-26.md` | Plan B's whole-branch review — the systemic-pattern section is the reason "who calls this?" is a standing risk |
| `.superpowers/sdd/planc1-task-1-{brief,report,review-package}.md` | Task 1's artifacts, as the shape to copy for tasks 2-14 |
| `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/subagent-driven-development/scripts/` | `task-brief` and `review-package`. **`review-package` is 4-arg:** `<PLAN> <BASE> <HEAD> <OUT>` |

---

## 5. Next actions, in sequence

1. **Verify this handoff before trusting it.** Done = all five agree with §2.
   ```bash
   git -C . log --oneline -1                        # expect 168f412
   git -C . status --porcelain                      # expect only the 4 pre-existing entries
   bash ossify/tests/run-all.sh                     # expect ALL GREEN (17 files)
   bash ossify/tests/eval/lib/aggregate-scores.sh   # expect TOTAL 23/23, exit 0
   for t in tests/test-*.sh; do bash "$t" >/dev/null || echo "ROOT-FAIL: $t"; done
   ```
2. **Read `.superpowers/sdd/progress.md` end to end**, then the plan's Global Constraints + D1-D9. Done = you can state why `pending_status` exists without re-reading.
3. **Task 2 (C1-2): pending-amendment lifecycle, quarantine provenance, fake lifecycle.**
   ```bash
   S=~/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/subagent-driven-development/scripts
   "$S/task-brief" docs/superpowers/plans/2026-07-29-ossify-plan-c1.md 2 .superpowers/sdd/planc1-task-2-brief.md
   ```
   Dispatch a **sonnet** implementer with the brief path, the Global Constraints, and the load-bearing line: *"the brief's literal code may contain a bug — if a test won't pass with it, debug the impl to satisfy the test's INTENT and document the deviation."* Done = commit + report at `.superpowers/sdd/planc1-task-2-report.md`.
4. **Review Task 2.** `"$S/review-package" <PLAN> ff24d06 <HEAD> .superpowers/sdd/planc1-task-2-review-package.md` — **BASE is `ff24d06`** (Task 1's commit), read from the ledger, **never `HEAD~1`**. Dispatch a sonnet reviewer with the task's own named risks from the plan **plus the standing "who calls this?"**. Done = APPROVED, or fix rounds closed.
5. **Controller-verify inline** rather than spending a re-review subagent on small prescribed fixes: `git diff` + run the suites + **mutation-test the new guard**. Task 2's mutation is specified in its Step 7 — drop the `(.pending_by // null) == $p.spine` conjunct and confirm the scoping assertion goes RED. Done = RED observed, lib restored byte-identical.
6. **Ledger line**, then Task 3. Repeat through Task 14.
7. **At Plan C1 close:** whole-branch review structured as N dimension-scoped reviewers reading HEAD state with the diff available for lookups (a single reviewer skims a diff this size — that is how Plan B's review had to be restructured), then `superpowers:finishing-a-development-branch`. **Revisit the merge decision there**, per the Plan B→C handoff's reasoning.

---

## 6. Traps

- **Do NOT re-dispatch any Plan A, B, or C1-Task-1 work.** The ledger and `git log` are authoritative over recollection.
- **Do NOT `git clean -fdx`** — it destroys `.superpowers/sdd/progress.md`, the recovery map.
- **Do NOT touch `README.md`** — the user's own uncommitted edit, dated 07-11. A pre-existing working-tree modification is not evidence of damage; check `mtime` before accusing.
- **Do NOT `git add -A`** — always explicit paths. Unrelated files live in the tree.
- **Do NOT register ossify in `.claude-plugin/marketplace.json`** or add a `.codex-plugin` manifest. That is Plan D's ship gate, and early registration breaks `tests/test-codex-dual-publish.sh`.
- **Do NOT trust a green mutation test.** No RED means you mutated the wrong thing — trace the real call path first. Task 2's originally-drafted mutation could not go RED; the plan now specifies one that can, and says why.
- **Do NOT reason about shell semantics under this session's zsh** (§3.4).
- **Do NOT let a reviewer "fix back"** the three deliberate divergences from the source: close **auto-applies** spec-aligned dispositions (D3), `oss demo_run` **requires a manifest** from Task 6 (§3.8), and there is **no template engine, ever** (D6).
- **Do NOT read subagent output files** at `/private/tmp/.../tasks/*.output` via shell — they are full JSONL transcripts and will overflow context. Use the returned result or the workflow `journal.jsonl`.
- **architect-critic invocation — the only supported form:** `export ARCHITECT_CRITIC_ARGS="--spec \"<abs path>\" --close"` then a bare `Skill(architect-critic:critiquing-spec)`. No `target=`/`depth=` parameters; both failure modes are silent. Do not copy the grammar shipped in `scaffold-onboard` (issue #116, still open, separate branch).
- **Git ops:** the agent does all of them. The auto-mode classifier still blocks `gh pr merge` and direct `git push origin main` until explicit in-turn authorization.

---

## 7. Read-out

```
Handoff read-out — ossify Plan C1, Task 1 → Task 2
  Location   docs/superpowers/handoffs/  (precedent: 2 prior handoffs live here, tracked)   tracked: yes
  §2 State   8 claims, each with an as-of and a command that checks it
  §3 Value   the plan review's 3 structural CRITICALs + the zsh-invisible shell class + §8.1 being unreliable
  §4 Refs    9 pointers — nothing pasted that a path could carry
  §5 Order   7 steps; step 1 is a 5-command verification of this document's own claims
  Weakest    §3.8 and the D3/D6 divergences are stated here but their real defence is the plan text;
             if a future reviewer reads only this handoff they could still argue them back
```
