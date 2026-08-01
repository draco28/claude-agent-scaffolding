# Session Handoff — ossify Plan C1, Tasks 3-7 done → Task 8 next

**Authored against the approved session-handoff v2 design** (`docs/superpowers/specs/2026-07-29-session-handoff-v2-design.md`): six-section core, claims written checkable, references pointed at rather than copied. Hand-authored for the same reason as its three predecessors — the v2 *skill* is Plan C2 work, and the v1 skill refuses without a pairing manifest this repo does not have.

Third live dogfood. Its predecessor's read-out named §3.6's population-estimate argument as its weakest point; the equivalent weak claim here is named in §7 rather than left for a reader to find.

**This one fixes a defect both predecessors shipped.** Each recorded a base commit that was stale before it was even read, because a handoff cannot know its own commit hash. §2 and §5 now state the *rule* and make you run the command, rather than naming a hash.

---

## 1. Orientation

ossify is a skeleton-first lifecycle plugin replacing the scaffold-onboard + scaffold-dev pair. Plans A and B shipped its state engine and its three planning skills. **Plan C1 is the execution engine and both close ceremonies** — the half that makes *"the product still runs"* a checked fact rather than an assumption.

**Tasks 1-7 of 14 are done, verified, and committed. 7 remain.** Rounds 1 (state layer) and 2 (new libs) are closed. **Round 3 is open**: T7 built the *callee*; T8 builds the *caller*.

The seam you are landing on is a good one. T7 pinned two contracts in files you can read directly — the return-JSON shapes and the ten-section report contract — so T8 needs nothing from the previous session's conversation.

**Do first:** run §5 step 1. Believe nothing here until it passes.

---

## 2. State — as checkable claims

| Claim | How to check |
|---|---|
| Branch `feat/ossify-core`, **65 ahead** of `main`, 0 behind, deliberately unmerged | `git rev-list --left-right --count main...HEAD` |
| **HEAD is this handoff's own commit.** The last *work* commit is `697be57` | `git log --oneline -3` |
| ossify suite: **19 files, ALL GREEN, 557 assertions** | `bash ossify/tests/run-all.sh` |
| eval gate: **23/23, exit 0** (C1 adds a 6th surface at T14 → 28) | `bash ossify/tests/eval/lib/aggregate-scores.sh` |
| repo-root parity suite clean | `for t in tests/test-*.sh; do bash "$t" \|\| echo "ROOT-FAIL: $t"; done` |
| Working tree carries only pre-existing noise: ` M README.md` + three untracked paths | `git status --porcelain` |
| Skill line budgets: `start` 499, `plan-spine` 499, `plan-release` 461, `work-item` 382 | `for f in ossify/skills/*/SKILL.md; do wc -l "$f"; done` |
| Schema is **v3** (`pending_amendments[]`); rc 8 exists and is confined to `worktree.sh` | `grep -n 'OSS_STATE_SCHEMA_VERSION=' ossify/lib/state.sh; grep -rlE 'return 8\b' ossify/lib/` |
| Tasks 3-7 = 11 commits | `git log --oneline 8853fe0..697be57` |

**Base for T8's review-package — a rule, not a hash.** It is **the commit before T8's first commit**, i.e. whatever `git log --oneline -1` shows *at the moment you generate the package*. That will be this handoff's commit. Do **not** copy a hash out of this document or the ledger: both prior handoffs recorded their own pre-commit HEAD and were stale on arrival (`ff24d06` and `eb1f815` were both wrong this way). Re-read `git log` then.

**Not verified, flagged rather than asserted:** the `/doctor` skill-listing budget has not been re-measured since Plan B. T14 owns it. `work-item` is the first new entry skill since then, so the number has certainly moved.

---

## 3. Uncodified context

**3.1 — The pre-dispatch plan sweep is now a standing step, and it has paid every single time.** Before briefing any task, verify that task's literal code and citations against the tree. Hit rate across Tasks 3-7: **T3** four stale citations (two would have broken the tests outright), **T4** the worktree spawn left the canonical repo dirty, **T6** two defects — a fixture that contradicted the task's own Step 1, and a wrong file list — **T7** a three-way self-contradiction. Only T5 came back clean. **Budget for this; it is not optional overhead.**

**3.2 — When a plan contradicts itself, grep the WHOLE task before fixing one line.** T7's Step 4 said "do NOT add an `agents` key" while the Files list said to add it, the `git add` staged it, *and named risk 4 told the reviewer to verify its shape*. Implementer and reviewer would both have been pointed the same wrong way. A contradiction is rarely confined to the line that states it — Files lists, git-add lines and reviewer checklists all restate the same instruction.

**3.3 — Three distinct ways a test can be incapable of failing. All three were found live in this session.**
1. **Tautological round-trip** — the verifier re-derives its expected value from what the code under test just wrote. `state_restore`'s test could not detect a restore that destroyed the entire journal; the suite stayed ALL GREEN at 473/473.
2. **Fixture never trips the precondition** — T6's scoping fixture did not match the runner-detection regex, so the assertion passed whether or not the fix existed.
3. **The harness supplies the property under test** — a cwd-containment assertion wrapped in `t_capture`, which is `T_OUT="$("$@" 2>&1)"`; the command substitution forks a subshell and contains *every* `cd`, regardless of the code under test.
All three read correctly, pass, and are invisible to review. **Only mutation finds them.** For ambient state (cwd, env, umask, traps) always ask: *does my harness isolate this?*

**3.4 — Mutation discipline, three rules, each learned by getting it wrong.** (a) Sanity-check that the mutated code still RUNS on its happy path — a syntax-broken mutation throws unrelated assertions RED and reads as coverage. (b) **Line-address every mutation**: a global `sed` on `state.sh` hit the loop in `oss_state_replay` as well as the one in `_oss_state_restore_body`, broke replay itself, and produced five REDs that looked like refutation. (c) **When a mutation does NOT go RED, ask whether you mutated the whole threat before declaring the assertion decoration.** `git worktree remove` refuses a dirty worktree on its own, so neutering our guard alone changes nothing — but neutering it *and* adding `--force` reds four assertions.

**3.5 — The DAG's `∥` means no logical dependency, not no file collision.** T4 and T5 are marked parallel and both append to `ossify/lib/commands.sh`. They were run sequentially for that reason. The same hazard bit the T3 review: four concurrent reviewers were told to mutation-test, and one left a stray mutation in `commands.sh` that a sibling reviewer found and reverted mid-review. **Run reviewer mutation experiments against a copy of the tree, not the shared checkout.**

**3.6 — A failed dispatch has not necessarily done nothing.** T5's implementer died on a stream watchdog after writing a 139-line lib, a 113-line test file and five wrappers — all uncommitted, no report. Re-dispatching would have duplicated finished work; discarding would have thrown away a correct implementation. **Read the tree first**, then choose retry / inline-finish / discard. The stall was not a product hang: three back-to-back full-suite runs simply outran the watchdog. Every dispatch since carries a run budget ("single test file while iterating, full suite at most twice"). When you inline-finish someone else's work, you owe it the verification the missing report would have carried.

**3.7 — Two shipped agent files have invalid YAML frontmatter, and it is NOT ossify's to fix here.** `scaffold-dev/agents/implementer-agent.md` and `scaffold-onboard/agents/derivation-reviewer.md` both fail parsing (unquoted scalar containing `": "`). It shipped because **the repo-root parity suite validates `SKILL.md` frontmatter only and never looks at `agents/*.md`**. ossify's own agent file is valid — its description is single-quoted. Filed as a background task; do not fold it into C1.

**3.8 — Nothing authors the handoff that `work-item` consumes. That is T8's job.** `grep -rin handoff ossify/skills/plan-spine/` returns nothing, and `plan-spine/SKILL.md:36-38` explicitly disclaims execution. T7 was therefore written against the handoff's **field contract** rather than a section-numbered template, so it stays correct whichever lane authors it. T8 must produce a handoff carrying at minimum: worktree abs path, declared branch, spec path, verification commands, and a Constraints block with `git_policy: STAGE-not-commit` and the return JSON shape.

---

## 4. References — pointers, not copies

| Path | What's here |
|---|---|
| `.superpowers/sdd/progress.md` | **The ledger — ground truth.** Gitignored scratch: read it, never `git clean` it. Per-task records for T1-T7 with every controller verification and every deviation |
| `docs/superpowers/plans/2026-07-29-ossify-plan-c1.md` | **The plan.** 14 tasks, 5 rounds. Global Constraints (lines 11-38) are binding and must be pasted into every dispatch — `task-brief` does **not** include them. D1-D9 explain why the naive reading of the spec is wrong in nine places |
| `ossify/skills/work-item/references/returns.md` | **T8's input contract** — both JSON shapes, byte-exact. T8 consumes these |
| `ossify/skills/work-item/references/report-contract.md` | The ten pinned report sections. `## 9. Suggestions for memory bank` is a cross-task join key T12 greps verbatim |
| `docs/superpowers/specs/2026-07-11-poc-first-lifecycle-design.md` | Main spec. C1 scope = §6, §6.1, §6.2. §9.2 state-safety is BINDING |
| `docs/superpowers/specs/2026-07-12-public-private-boundary-design.md` | Companion. §4.2/§4.3 shape close; multi-repo itself is Plan D |
| `docs/superpowers/handoffs/2026-07-31-ossify-plan-c1-task-2-to-3.md` | Immediate predecessor. Its §3 gotchas still govern |
| `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/subagent-driven-development/scripts/` | `task-brief` and `review-package`. **`review-package` is 4-arg:** `<PLAN> <BASE> <HEAD> <OUT>` |

---

## 5. Next actions, in sequence

1. **Verify this handoff before trusting it.** Done = all six agree with §2.
   ```bash
   git -C . log --oneline -3
   git -C . status --porcelain                          # expect only the 4 pre-existing entries
   git -C . rev-list --left-right --count main...HEAD   # expect 0<TAB>66 (65 + this handoff)
   bash ossify/tests/run-all.sh                         # expect ALL GREEN (19 files)
   bash ossify/tests/eval/lib/aggregate-scores.sh       # expect TOTAL 23/23, exit 0
   for t in tests/test-*.sh; do bash "$t" >/dev/null || echo "ROOT-FAIL: $t"; done
   ```
2. **Read `.superpowers/sdd/progress.md` end to end**, then the plan's Global Constraints + D1-D9. Done = you can say why `pending_amendments` is a list and why C1 ships no rule evaluator, without re-reading.
3. **Run the pre-dispatch sweep on Task 8** (§3.1 — it has found a defect in 4 of the last 5 tasks). Verify every file path, line number, function name and cross-task claim in T8's text against the tree. **T8's file lists were written before Rounds 2-3 existed**, and Round 2 alone added two test files that invalidated T6's list. Correct the plan and commit that correction *before* briefing.
4. **Task 8 (C1-8): round orchestration — the execution lane that drives a work item.**
   ```bash
   S=~/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/subagent-driven-development/scripts
   "$S/task-brief" docs/superpowers/plans/2026-07-29-ossify-plan-c1.md 8 .superpowers/sdd/planc1-task-8-brief.md
   ```
   Dispatch an **opus** implementer (skill-authoring, prose is eval-gated) with the brief path, **the Global Constraints pasted in**, a **run budget** (§3.6), and the load-bearing line: *"the brief's literal code may contain a bug — if a test won't pass with it, debug the impl to satisfy the test's INTENT and document the deviation."*
5. **Controller-verify, do not delegate the verification.** Grep the tree for every test the report claims; mutate every guard and confirm a *specific* named RED; re-measure counts against the tree. §3.3 and §3.4 are the checklist. On a task this prose-heavy, also confirm every `oss` verb named in the prose resolves via `bash ossify/bin/oss help`, and that no citation points at a section that does not exist.
6. **Ledger line**, then T9. Round 3 is T7→T11 strictly sequential — each consumes the previous one's contract, so there is no parallelism to recover time with.
7. **At Plan C1 close:** whole-branch review structured as N dimension-scoped reviewers reading HEAD state with the diff available for lookups (a single reviewer skims a diff this size — that is how Plan B's review had to be restructured), then `superpowers:finishing-a-development-branch`. **Revisit the merge decision there.**

---

## 6. Traps

- **Do NOT re-dispatch any Plan A, B, or C1 Task 1-7 work.** The ledger and `git log` are authoritative over recollection.
- **Do NOT copy a base commit out of any document.** Re-read `git log` when you generate the review package (§2). Both predecessors got this wrong.
- **Do NOT "fix back" the five deliberate divergences**, each of which looks like a bug to a reviewer reading only the plan: `pending_amendments` is a **list** (user decision); `ledger_unplan` **requires** `<spine>`; `close` **auto-applies** spec-aligned dispositions (D3); there is **no template engine, ever** (D6); and C1 ships the verification gate **without** a machine-checkable-rule evaluator (D2).
- **Do NOT add an `agents` key to any `plugin.json`.** No plugin in this repo has one; two ship working `agents/` directories. Registration is by directory convention.
- **Do NOT trust a green mutation test — or a red one** — until you have confirmed the mutated code still runs (§3.4).
- **Do NOT believe a report's claim that a test was added.** Grep the tree.
- **Do NOT reason about shell semantics under zsh** — it runs the last pipeline element in the parent shell and hides an entire bug class. `run-all.sh` forces `bash` for exactly this reason.
- **Do NOT `git clean -fdx`** — it destroys `.superpowers/sdd/progress.md`, the recovery map.
- **Do NOT touch `README.md`** — the user's own uncommitted edit, dated 07-11. A pre-existing working-tree modification is not evidence of damage; check `mtime` before accusing.
- **Do NOT `git add -A`** — always explicit paths. Unrelated files live in the tree.
- **Do NOT register ossify in `.claude-plugin/marketplace.json`** or add a `.codex-plugin` manifest. That is Plan D's ship gate, and early registration breaks `tests/test-codex-dual-publish.sh`.
- **`start` and `plan-spine` are at exactly 499/500.** Any edit that adds a line needs a trim in the same commit. `work-item` has 68 lines of headroom and T8's reference is what it was reserved for.
- **architect-critic — the only supported form:** `export ARCHITECT_CRITIC_ARGS="--spec \"<abs path>\" --close"` then a bare `Skill(architect-critic:critiquing-spec)`. No `target=`/`depth=` parameters; both failure modes are silent.
- **Do NOT read subagent output files** at `/private/tmp/.../tasks/*.output` for *agent* tasks — they are full JSONL transcripts and will overflow context.
- **Git ops:** the agent does all of them. The auto-mode classifier still blocks `gh pr merge` and direct `git push origin main` until explicit in-turn authorization.

---

## 7. Read-out

```
Handoff read-out — ossify Plan C1, Tasks 3-7 → Task 8
  Location   docs/superpowers/handoffs/  (precedent: 4 prior handoffs live here, tracked)  tracked: yes
  §2 State   9 claims, each with a command that checks it; all six §5-step-1 commands run before commit
  §3 Value   the pre-dispatch sweep's 4-of-5 hit rate + THREE distinct ways a test cannot fail,
             all found live + the three mutation-discipline rules, each learned by getting it wrong
  §4 Refs    8 pointers — nothing pasted that a path could carry
  §5 Order   7 steps; step 1 is a 6-command verification of this document's own claims,
             step 3 makes the pre-dispatch sweep an explicit gate rather than an implicit habit
  §6 Traps   13, incl. the base-commit rule that both predecessors got wrong
  Fixed      both predecessors recorded a base hash that was stale before it was read.
             §2 and §5 state the RULE and make you run the command instead.
  Weakest    §3.1's "budget for this" is asserted from a 4-of-5 hit rate over five tasks — a real
             pattern, but a small sample, and the tasks were not independent (T3 and T6 failed for
             the same stale-line-number reason). If T8's sweep comes back clean, that is evidence
             the rate is dropping as the plan's untouched regions shrink, not that the sweep was
             skippable. Cheap to re-check: it is one grep pass before each brief.
```
