# Session Handoff — ossify Plan C1, Task 2 done → Task 3 next

**Authored against the approved session-handoff v2 design** (`docs/superpowers/specs/2026-07-29-session-handoff-v2-design.md`): six-section core, claims written checkable, references pointed at rather than copied. Hand-authored for the same reason as its predecessor — the v2 *skill* is Plan C2 work, and the v1 skill refuses without a pairing manifest this repo does not have.

Second live dogfood of that design. Its predecessor's §7 read-out named "a future reviewer could argue the divergences back" as its weakest point; that is addressed here by moving every divergence into §6 as an explicit do-not-revert, and by recording the *reason* beside each rather than the instruction alone.

---

## 1. Orientation

ossify is a skeleton-first lifecycle plugin replacing the scaffold-onboard + scaffold-dev pair. Plans A and B shipped its state engine and its three planning skills. **Plan C1 is the execution engine and both close ceremonies** — the half that makes *"the product still runs"* a checked fact rather than an assumption.

**Tasks 1 and 2 of 14 are done, reviewed, and approved. 12 remain.**

Task 2 cost five commits rather than one. That is not drift — a review found a design gap D1 never considered, the user resolved it, and a second review found that the fix round's *code was right and its tests were not*. Both are recorded below, because the second is the more transferable lesson.

**Do first:** run §5 step 1. It is a six-command block that checks this document's own claims. Believe nothing here until it passes.

---

## 2. State — as checkable claims

Every claim carries a way to check it. If one fails, stop and reconcile before starting work.

| Claim | How to check |
|---|---|
| HEAD is `eb1f815`, branch `feat/ossify-core` | `git log --oneline -1` |
| **53 ahead** of `main`, **0 behind**; branch deliberately unmerged | `git rev-list --left-right --count main...HEAD` |
| ossify suite: **17 files, ALL GREEN, 448 assertions** | `bash ossify/tests/run-all.sh` |
| eval gate: **23/23, exit 0** (C1 adds a 6th surface at T14 → 28) | `bash ossify/tests/eval/lib/aggregate-scores.sh` |
| repo-root parity suite clean | `for t in tests/test-*.sh; do bash "$t" \|\| echo "ROOT-FAIL: $t"; done` |
| Working tree carries only pre-existing noise: ` M README.md` + three untracked paths | `git status --porcelain` |
| `plan-spine/SKILL.md` is **499/500** — one line of headroom, deliberately restored | `wc -l ossify/skills/plan-spine/SKILL.md` |
| Task 2 = 5 commits: `68077d0` impl, `51440bd` fix 1, `cbd78b5` fix 2, `680c8ad` + `eb1f815` plan corrections | `git log --oneline 60fddd5..HEAD` |
| Schema is now **v3** (`pending_amendments[]`); migration carries v1 **and** v2 in one op | `grep -n 'OSS_STATE_SCHEMA_VERSION=' ossify/lib/state.sh` |

**Not verified, and flagged rather than asserted:** the `/doctor` skill-listing budget has not been re-measured; no entry skills have been built yet, so nothing has moved. T14 owns the re-measure.

---

## 3. Uncodified context

What is true but written nowhere else. `.superpowers/sdd/progress.md` carries the long form; this is what a fresh reader most needs.

**3.1 — The pending model changed by user decision, and it is not a regression against D1.** D1 gave each demo line a single pending-amendment slot. Two spines amending the same line meant the second silently overwrote the first, and the first spine's close then applied nothing — verified live. That is exactly the silent-coverage-loss harm D1 was created to prevent. **The user chose the general fix: `pending_amendments[]`, one entry per spine, each close applying and consuming only its own.** `ledger_unplan` gained a required `<spine>` as a direct consequence — with a list, "clear the pending amendment on d1" is ambiguous, and clearing all of them silently would reinstate the very footgun the list removes. **Both diverge from the plan's prescribed code by design.**

**3.2 — The most transferable lesson: a fix round's code can be right while its tests are worthless.** `51440bd` added four guards. Three had **zero coverage** — reverting each left all 17 suites GREEN — and the fix report *claimed* a regression test that did not exist in the tree. The rule "reports are directionally reliable but their counts are not" now extends to **"reports' claims about what was committed are not either — grep the tree for the named test."**

**3.3 — And the method trap underneath it, which bit me personally.** My first mutation of the F2 guard produced broken *jq* rather than a semantic change. The op failed outright, three unrelated assertions went RED, and I read that as coverage. A valid mutation left everything green: the finding was real and I had published a wrong refutation. **The known rule is "no RED means you mutated the wrong thing"; the inverse is just as true and fails in the flattering direction. Sanity-check that a mutated op still works on its happy path before believing any suite result.** Use an exact-match replacement that asserts occurrence count, not a regex.

**3.4 — A plan reviewed at time T is not a safe input at time T+1.** Task 2 changed the state shape, and a sweep of the whole remaining plan found **two later tasks' prescribed code silently broken by it** — T3's three doctor selectors and T11's fake-expiry gate. Both failed *silently green*: T3's warning could never fire, and T11's blocking gate would let a fake renewed to expire at r2 sail past r2's close untouched. Both are corrected (`680c8ad`, `eb1f815`) with a mandate that each task's test prove the gate can actually **fire**. Tasks 4-10 and 12-14 checked clean. **Re-run this sweep after any future task that changes a state shape** — grep the plan for the old field names, not just the current task's files.

**3.5 — `apply_demo_pending`'s twin taught the payload-shape lesson twice.** F2 gave `set_demo_line_status` back-compat for journal payloads written before the field existed; the same reasoning was *not* applied to `clear_demo_pending`, whose payload also changed. Replaying a pre-F1 entry resurrected an unplanned amendment and made `oss doctor` report `fail: replay` on a state that was correct. **When an op's payload shape changes, audit every sibling op in the same change.**

**3.6 — Known bounded limitation, deliberately not fixed.** A journal written by `68077d0` in which two spines planned on the *same* line replays as "accumulate both" rather than v2's "second overwrites first". Unlike the above there is no payload marker to branch on — both builds write identical payloads — so a real fix needs version-aware replay (a schema stamp per journal entry), a mechanism nothing else needs. Exposed population: states created by a build that lived about an hour on an unmerged branch, i.e. **zero**. Revisit only if journal-entry versioning arrives for another reason.

**3.7 — Plan-internal identifiers do not belong in shipped prose.** `D1`, `F1`, `Task 11` had leaked into `ossify/skills/**`; they name rows in a document no user of the plugin can read, and `(F1:` collided with plan-spine's own F1-F6 demo-floor vocabulary. All stripped. **Spec §-references are fine — the spec is the product's own design record. Plan references are not.**

**3.8 — Doctor's pending/quarantine visibility is T3's, and prose was made honest about HEAD.** `demo-amendments.md` §4 and §6 both promised `oss doctor` surfaces these; it does not yet. Both were rewritten to describe HEAD truthfully. **T3 should re-add the doctor references once its `warn:` lines actually ship** — that is the intended end state, not an omission.

---

## 4. References — pointers, not copies

| Path | What's here |
|---|---|
| `.superpowers/sdd/progress.md` | **The ledger — ground truth.** Gitignored scratch: read it, never `git clean` it. Carries D1-D9, the execution protocol, and the full Task 1 + Task 2 records including both fix rounds |
| `docs/superpowers/plans/2026-07-29-ossify-plan-c1.md` | **The plan.** 14 tasks, 5 rounds. Global Constraints (lines 11-38) are binding and must be copied into every dispatch — `task-brief` does **not** include them. D1-D9 explain why the naive reading of the spec is wrong in nine places |
| `docs/superpowers/specs/2026-07-11-poc-first-lifecycle-design.md` | Main spec. C1 scope = §6, §6.1, §6.2. §9.2 state-safety is BINDING |
| `docs/superpowers/specs/2026-07-12-public-private-boundary-design.md` | Companion. §4.2/§4.3 shape close; multi-repo itself is Plan D |
| `docs/superpowers/specs/2026-07-29-session-handoff-v2-design.md` | Approved; **Plan C2 absorbs it as scoped tasks — do not re-derive**. Issue #113 |
| `docs/superpowers/handoffs/2026-07-31-ossify-plan-c1-task-1-to-2.md` | Predecessor. Its §3 gotchas still govern. **Its §5 step 4 names the wrong review-package base — see §6** |
| `.superpowers/sdd/planc1-task-2-{brief,report,fix-brief,fix-report,fix2-brief,fix2-report}.md` | Task 2's full paper trail, and the shape to copy |
| `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/subagent-driven-development/scripts/` | `task-brief` and `review-package`. **`review-package` is 4-arg:** `<PLAN> <BASE> <HEAD> <OUT>` |

---

## 5. Next actions, in sequence

1. **Verify this handoff before trusting it.** Done = all six agree with §2.
   ```bash
   git -C . log --oneline -1                        # expect eb1f815
   git -C . status --porcelain                      # expect only the 4 pre-existing entries
   git -C . rev-list --left-right --count main...HEAD   # expect 0<TAB>53
   bash ossify/tests/run-all.sh                     # expect ALL GREEN (17 files)
   bash ossify/tests/eval/lib/aggregate-scores.sh   # expect TOTAL 23/23, exit 0
   for t in tests/test-*.sh; do bash "$t" >/dev/null || echo "ROOT-FAIL: $t"; done
   ```
2. **Read `.superpowers/sdd/progress.md` end to end**, then the plan's Global Constraints + D1-D9. Done = you can say why `pending_amendments` is a list without re-reading.
3. **Task 3 (C1-3): `oss state_restore`, manifest/id dispatcher exposure, doctor growth.**
   ```bash
   S=~/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/subagent-driven-development/scripts
   "$S/task-brief" docs/superpowers/plans/2026-07-29-ossify-plan-c1.md 3 .superpowers/sdd/planc1-task-3-brief.md
   ```
   Dispatch a **sonnet** implementer with the brief path, **the Global Constraints pasted in** (the brief omits them), and the load-bearing line: *"the brief's literal code may contain a bug — if a test won't pass with it, debug the impl to satisfy the test's INTENT and document the deviation."* Done = commit + report at `.superpowers/sdd/planc1-task-3-report.md`.
4. **Review Task 3.** `"$S/review-package" <PLAN> eb1f815 <HEAD> .superpowers/sdd/planc1-task-3-review-package.md` — **BASE is `eb1f815`**, the commit before Task 3 begins. Dispatch reviewers with the task's own named risks **plus the standing "who calls this?"**, and add these two, learned the hard way on Task 2: **(a) for every guard this task adds, mutate it and confirm a specific RED — if nothing goes RED the guard is untested; (b) grep the tree for every test the report claims to have added.**
5. **Controller-verify inline** rather than spending a re-review subagent on small prescribed fixes: `git diff` + the three gates + mutation-test each new guard yourself. **T3's doctor step is the one to watch** — its three `warn:` lines must be proven to FIRE against a state seeded with a pending amendment, a quarantined line, and a *renewed* fake. A doctor check that counts zero forever passes every "is doctor green?" test ever written.
6. **Ledger line**, then Task 4. Rounds 2-5 follow the plan's DAG.
7. **At Plan C1 close:** whole-branch review structured as N dimension-scoped reviewers reading HEAD state with the diff available for lookups (a single reviewer skims a diff this size — that is how Plan B's review had to be restructured), then `superpowers:finishing-a-development-branch`. **Revisit the merge decision there.**

---

## 6. Traps

- **Do NOT re-dispatch any Plan A, B, or C1 Task 1/2 work.** The ledger and `git log` are authoritative over recollection.
- **Do NOT use `ff24d06` as any review-package base.** The predecessor handoff says so and it is wrong — that commit is *mid*-Task-1. The rule is **the commit before THIS task**, i.e. the END of the previous task's work, not any commit inside it.
- **Do NOT "fix back" the four deliberate divergences.** Each has a reason, and each will look like a bug to a reviewer reading only the plan: `pending_amendments` is a **list** (user decision, §3.1); `ledger_unplan` **requires** `<spine>` (consequence of the list); `close` **auto-applies** spec-aligned dispositions (D3); there is **no template engine, ever** (D6).
- **Do NOT trust a green mutation test — and do NOT trust a red one either** until you have confirmed the mutated code still runs (§3.3).
- **Do NOT believe a report's claim that a test was added.** Grep the tree (§3.2).
- **Do NOT reason about shell semantics under zsh** — it runs the last pipeline element in the parent shell and hides an entire bug class. `run-all.sh` forces `bash` for exactly this reason.
- **Do NOT `git clean -fdx`** — it destroys `.superpowers/sdd/progress.md`, the recovery map.
- **Do NOT touch `README.md`** — the user's own uncommitted edit, dated 07-11. A pre-existing working-tree modification is not evidence of damage; check `mtime` before accusing.
- **Do NOT `git add -A`** — always explicit paths. Unrelated files live in the tree.
- **Do NOT register ossify in `.claude-plugin/marketplace.json`** or add a `.codex-plugin` manifest. That is Plan D's ship gate, and early registration breaks `tests/test-codex-dual-publish.sh`.
- **Do NOT let plan-internal identifiers into shipped prose** (§3.7). Spec §-refs yes; `D1`/`F1`/`Task N` no.
- **`plan-spine/SKILL.md` has exactly one line of headroom (499/500).** Any edit that adds a line needs a trim in the same commit.
- **architect-critic — the only supported form:** `export ARCHITECT_CRITIC_ARGS="--spec \"<abs path>\" --close"` then a bare `Skill(architect-critic:critiquing-spec)`. No `target=`/`depth=` parameters; both failure modes are silent. Do not copy the grammar shipped in `scaffold-onboard` (issue #116, still open).
- **Do NOT read subagent output files** at `/private/tmp/.../tasks/*.output` for *agent* tasks — they are full JSONL transcripts and will overflow context. Workflow `.output` files are JSON results and are safe; use `jq`, not `cat`.
- **Git ops:** the agent does all of them. The auto-mode classifier still blocks `gh pr merge` and direct `git push origin main` until explicit in-turn authorization.

---

## 7. Read-out

```
Handoff read-out — ossify Plan C1, Task 2 → Task 3
  Location   docs/superpowers/handoffs/  (precedent: 3 prior handoffs live here, tracked)  tracked: yes
  §2 State   9 claims, each with a command that checks it; all six §5-step-1 commands run before commit
  §3 Value   the user's pending-list decision + the "right code, worthless tests" finding +
             the mutation-validity trap I fell into myself + the plan-staleness class (2 hits)
  §4 Refs    8 pointers — nothing pasted that a path could carry
  §5 Order   7 steps; step 1 is a 6-command verification of this document's own claims
  §6 Traps   corrects the predecessor's own wrong review-package base, and moves all four
             deliberate divergences here with their reasons attached
  Weakest    §3.6's bounded limitation is argued from a population estimate ("zero states exist"),
             not from a mechanism — if that estimate is ever wrong the reasoning does not degrade
             gracefully. It is cheap to re-check: any state file with schema_version 2 disproves it.
```
