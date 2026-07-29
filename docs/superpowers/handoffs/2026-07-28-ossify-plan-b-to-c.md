# Session Handoff — ossify Plan B complete → Plan C next

**Next-session focus:** Detail **Plan C** (execution + close) via `superpowers:writing-plans`, then execute it subagent-driven. Plan B is done and green; nothing on this branch is owed. Start by reading §0, then §6 — Plan C's inbox has three items that must be *decided*, not inherited.

**Type:** forward · **Scope:** plan-to-plan (B→C) · **Date:** 2026-07-28
**Branch:** `feat/ossify-core` @ `7342584` — 40 ahead of `main`, 0 behind, **deliberately unmerged**
**Repo:** `/Users/draco/projects/claude-agent-scaffolding` (marketplace repo; single-repo, no workspace-init manifest)

> Storage note: this repo's handoffs live **committed** at `docs/superpowers/handoffs/`, not in scaffold-dev's gitignored `.workspace/handoffs/`. That is why the Plan A→B handoff survived to be read this session. `scaffold-dev:handing-off-session` refuses durable mode without a pairing manifest; its *content* contract is followed here, its storage path deliberately is not.

---

## 0. Read these first (do not re-derive)

| Artifact | Why |
|---|---|
| `.superpowers/sdd/progress.md` (525 ln) | **The ground truth.** Per-task record of every bug, fix, reviewer verdict, and lesson across Plans A+B. Gitignored scratch — read it, never `git clean -fdx` it |
| `docs/superpowers/handoffs/2026-07-13-ossify-plan-a-to-b.md` (129 ln) | The predecessor handoff. Its §3 EXECUTION PLAYBOOK still governs; §4 gotchas still bite |
| `docs/superpowers/specs/2026-07-11-poc-first-lifecycle-design.md` (600 ln) | Main spec. **Plan C scope = §6–§8.** §9.2 state-safety is BINDING |
| `docs/superpowers/specs/2026-07-12-public-private-boundary-design.md` (293 ln) | Companion. Plan D scope, but §4.2/§4.3 shape Plan C's close |
| `.superpowers/sdd/FINAL-REVIEW-2026-07-26.md` (85 ln) | Final whole-branch review: 8 Important, systemic patterns, Minor triage |
| `docs/superpowers/plans/2026-07-17-ossify-plan-b.md` (1670 ln) | Plan B. Its **Series map** section sketches C and D; its Global Constraints block is reusable verbatim |
| `docs/conventions/evolutionary-architecture-playbook.md` (525 ln) | Doctrine layer for framing |
| `docs/superpowers/specs/2026-07-29-session-handoff-v2-design.md` (204 ln) | **Approved design Plan C must absorb** — `/handoff` is a redesign, not a port. See §6.1b |

---

## 1. Where we are

**Plans A + B are complete and reviewed.** Every gate green at `7342584`:

```
ossify suite    ALL GREEN (16 files)
repo parity     clean
eval gate       23/23, exit 0   (5 surfaces)
```

Built: `bin/oss` dispatcher + 9 libs (820 ln) + 16 test files (1361 ln) + 3 entry skills with 27 references (5596 ln) + a 5-surface eval harness.

**Branch kept unmerged — decided 2026-07-28.** Merging would *not* release: the install gate is `.claude-plugin/marketplace.json`, and ossify is absent from it and from `V0_PLUGINS`, shipping `0.1.0-dev`. Unregistered code on main is invisible to `/plugin install`. Merging was therefore safe but bought nothing (main hasn't moved since 07-10, 0 behind) and would drop the release gate from two locks to one. **Revisit at Plan C close.**

---

## 2. The 4-plan series (rolling wave — detail C only now)

- **Plan A — DONE.** State engine, dispatcher, ID grammar, ledger runner. `a4cf62e..dc8fce8`.
- **Plan B — DONE.** `start` / `plan-release` / `plan-spine` + substrate + eval harness. `576834f..7342584`.
- **Plan C — NEXT, detail it now.** Execution + close: `work-item` port, `close` router (work-item → spine bone/flesh → release), cumulative-demo runner, ledger walkthrough + amendments, release close (pin/publish, docs-increment trigger table, fake-expiry as a blocking finding, boundary-audit hook point), memory-bank harvest port, patch lane, utility command ports (`/handoff` `/defer` `/work-pr` `/adr` `/flip-adr` `/amend-spec` `/changelog` `/runbook`), pr_hierarchical port. **Spec §6–§8.**
  - **`/handoff` is NOT a straight port — it has its own approved design.** See `docs/superpowers/specs/2026-07-29-session-handoff-v2-design.md` (`b560b07`) and issue **#113**. Plan C absorbs it as scoped tasks; do not re-derive it. Headline: no deterministic gates, six-section core, location judged from repo evidence, two modes (compose + resume), chain model dropped, pure skill with no lib code, two new eval surfaces taking the gate 23 → 31.
- **Plan D — keep sketched.** Boundary + ship gate: workspace-init additive extension, multi-repo worktrees + cross-repo dep overrides, boundary audit, consolidated eval suite (**THE ship gate**), marketplace registration, Forge3D greenfield + pulse-trader adopt-forward pilots.

---

## 3. What's NOT in memory bank yet

The durable lessons from this session. Most are *not* in the specs and would be re-derived expensively.

**3.1 — The systemic finding, and it indicts the review method.** The final review's verdict: *"this branch verified that mechanisms exist. It did not verify that anything CALLS them."* Six of eight findings were producer/consumer wiring, not primitive correctness — and both bugs fixed earlier the same day (escalate-never-calling-`class_set`; plan-spine-not-reading-the-`[internal]`-marker) are the same shape. Per-task reviews consistently asked *"does this work?"* and never *"who calls this?"*. **Add "who calls this?" as a standing named risk in every Plan C task-review dispatch.**

**3.2 — Validators are looser than the prose promises, and the prose is the executable artifact.** `ledger.sh`'s `exit:[0-9]*` glob accepted `exit:0 (tests green)`, and `demo_run` then reported `PASS` for a command that exited 1 — in the artifact spec §6.1 designates *un-fakeable*, which is append-only. Two shipped docs promised "anything else exits 2". An over-promised guarantee is worse than a missing one: it is exactly what tells the author not to check. Same shape as the already-fixed `set_release_meta` arbitrary-key bug.

**3.3 — Prose has no CI.** No test anywhere extracts or executes a `SKILL.md` bash block. A skill can document a contract another skill never implements and nothing catches it. This is the structural fix for 3.1 and 3.2 and the final review called it *the single highest-leverage test investment in the series*. **Plan C should scope it explicitly rather than inherit it.**

**3.4 — Mutation testing: no RED means you mutated the wrong thing.** I mutated `oss_ledger_active_auto` to test a `demo_run` assertion; the suite stayed green because `demo_run` never calls it (it reads `.demo_ledger` directly). Trace the real call path before believing a green mutation.

**3.5 — Blanket "do not touch file X" is a worse instruction than naming the hazard.** I forbade the fix agent from editing `test-state-replay.sh` (its tail deletes the base snapshot). It edited the file *correctly* — inserting before the deletion, inspecting already-captured output. The agent that understands the hazard can satisfy it in ways the blanket rule forbids.

**3.6 — Review severity needs a reachable-at-HEAD trigger.** The final review demoted 6 of 7 Criticals on adversarial verification, almost always because the reviewer reasoned from binding spec text to harm without checking the harm path exists yet. Half of ossify's consumers (`close`, `work-item`, doctor entry skill, worktrees) are Plan C/D. Require a reachable trigger before anything is called Critical.

**3.7 — Infrastructure noise can enter a measurement channel.** The classifier outage prepended a note to stage-1 agent outputs; the eval pipeline feeds stage-1 output verbatim into the judge, so the note was being *scored as the skill's reasoning*. A contamination guard now detects/strips/flags it — and fired on 3 of 46 agents the first run it existed. **Any pipeline that pastes one agent's output into another agent's prompt needs a provenance check at that boundary.** Note the failure mode: the earlier outage failed *loudly* (agents refused); this one failed *quietly*.

**3.8 — Eval protocol (not written down elsewhere).** The invoke agent must receive the fixture **body only**, frontmatter stripped — the frontmatter is the answer key. The judge sees the full fixture. The implementer subagent **cannot** run evals (no subagent nesting); the controller runs them as a Workflow. Corollary: **whoever has read the fixture keys cannot serve as the invoke agent** — that is why the eval could not be run inline during the outage.

**3.9 — De-leakage discipline.** B8's implementer stripped the fixtures' own wording from its shipped prose and re-domained the examples, reasoning that an eval agent reads SKILL.md + references so leaving it in turns fixtures into recall. It deliberately raised its own miss probability to keep the eval honest — and the fixture it named most-at-risk still passed. Preserve this in Plan C.

**3.10 — Implementer reports are directionally reliable but their counts are not.** Two consecutive reports had factual slips (B8: "the only accept case" — there were two; B9: "15 suites" — there were 16; "2 stronger assertions" — there were 5). Verify counts against the tree.

**3.11 — `resumeFromRunId` replays cached results.** After a contaminated or degraded workflow run, a resume is **not** clean — it replays the bad results. A fresh run is required.

---

## 4. The execution playbook (unchanged from the A→B handoff §3 — it held)

Replicate exactly. The 9 bugs Plan A's review layer caught and the ~20 Plan B's caught were caught *because* of this discipline.

- **Rolling wave.** Detail only Plan C now. Keep D as the series-map sketch.
- **Per task:** ledger check → `scripts/task-brief <plan> N <outfile>` → dispatch implementer → `scripts/review-package <PLAN_FILE> <BASE> <HEAD> <OUTFILE>` (note the 4-arg signature; BASE = commit before *this* task, from the ledger, **never `HEAD~1`**) → dispatch task reviewer with **specific named risks** → fix rounds → ledger line.
- **Models:** sonnet for transcription/test/code tasks; **opus for skill-authoring tasks whose prose is eval-gated** (B6/B7/B8 were opus, B9 was sonnet); sonnet reviewers; **opus for the final whole-branch review**.
- **Scripts:** `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/subagent-driven-development/scripts/{task-brief,review-package}`.
- **The load-bearing dispatch line:** *"the brief's literal code may contain a bug — if a test won't pass with it, debug the impl to satisfy the test's INTENT and document the deviation."* It found real defects in **8 of 8** Plan B tasks.
- **Standing instruction:** any verification the implementer performs that guards a behavior this task introduces **must be committed as a test**. B1, B3 and B7 all needed fix rounds for exactly this omission.
- **Fix routing:** finding that makes code match the plan's *stated intent* → just fix it. Finding that **contradicts** the design → present finding + plan text to the user and ask which governs (this fired once in Plan B — finding 2, see §6.1).
- **Controller verification:** for small reviewer-prescribed fixes, verify inline (git diff + run tests + **mutation-test** the new guard) rather than spending a re-review subagent.
- **Final review:** a single reviewer over a 728KB diff will skim. Structure it as N dimension-scoped reviewers reading **HEAD state** (small) with the diff available for targeted lookups, then adversarially verify every Critical/Important with a refute-by-default verifier. That is what produced 8 real findings from 46 raised.

---

## 5. Recurring technical gotchas (Plan C extends the SAME libs)

All of the A→B handoff §4 list still applies. Carry it forward verbatim; the highest-frequency offenders:

1. Bare `x="$(cmd)"` under `set -e` between lock-acquire and lock-release **leaks the lock permanently**. `state.sh` suspends errexit via the `_oss_state_mutate_body … || rc=$?` pattern — any new mutating ceremony MUST follow it.
2. Unguarded `jq` that finds nothing → nonzero rc → aborts the dispatcher.
3. `[ "$v" -gt N ]` on non-numeric `$v` errors and reads as false inside `if` — silent pass. **This is the exact mechanism of the demo-ledger bug (§3.2).**
4. `… | while read` runs the loop in a subshell; use `< <(process substitution)`.
5. `_oss_apply_op` ops MUST be pure deterministic jq — both mutate and replay route through them.
6. Tests source libs **without** `set -e`; `bin/oss` runs with it. Test through the dispatcher path or strict-mode faults are structurally invisible.
7. **Never wrap harness assertions in `( … )` subshells** — `T_PASS`/`T_FAIL` mutations are lost, producing visible FAIL lines with exit 0.
8. **Do NOT append to `tests/test-state-replay.sh`** — it tampers live state and deletes its base snapshot before its tail. (Inserting *before* the deletion is fine — see §3.5.)
9. rc taxonomy: 1 generic · 2 usage · 3 lock · 4 apply · 5 drift · 6 schema · 7 unknown-ref. Do not introduce overlapping codes.

---

## 6. Carried-forward state — Plan C's inbox

### 6.1 DECIDE, don't inherit: the demo-amendment timing divergence
`oss ledger_supersede` / `ledger_retire` apply **immediately**; spec §5.3 says they apply **at the spine's close**. Four prose sites were corrected to describe the lib's real behavior (`a53d034`) and the divergence is recorded inline in `plan-spine/references/demo-amendments.md`. **Plan C must decide which side moves, in its design section, before building `close`** — whoever builds it will find the lib already does the simple thing and may never notice §5.3 said otherwise. Options weighed and recorded in the ledger: add `pending_status` (spec-faithful, but creates state nothing consumes until `close` ships — the built-but-unwired pattern §3.1 names) vs. amend §5.3.

### 6.1b Session handoff v2 — designed, approved, awaiting Plan C
`docs/superpowers/specs/2026-07-29-session-handoff-v2-design.md` (`b560b07`) · issue **#113** (retitled, scope widened; the original parse-truncation report is preserved verbatim at its bottom).

The v1 skill refuses without a pairing manifest — reproduced live *in this repo*, which is why the handoff you are reading was authored by hand rather than by `/handoff`. The coupling is four layers deep (storage anchor, the `sprint|slice|mid-slice|bugfix|techdebt` scope enum, a template defining state pointers as "sprint/slice IDs, worktrees", and sprint-keyed retention).

**Absorb the design's task set into Plan C; do not re-derive it.** What it settles: no deterministic gates anywhere in the runtime path · six-section core (`Orientation`/`State`/`Uncodified context`/`References`/`Next actions, in sequence`/`Traps`) · location judged from repo evidence and stated in one line · tracked-vs-gitignored as a deliberate decision (v1's gitignored storage is why handoffs die with the machine) · read-out at runtime + eval surfaces at build time · compose **and** resume modes, where §2's claims are written checkable precisely so resume can verify them · forward/return chaining dropped, which removes the short-ids, filename regex and scope prefix that existed only to serve it · pure skill, zero lib code, zero listing cost.

It also forces **two amendments to the main ossify spec**: §8.1's catalog row still reads `handing-off-session → **Unchanged**` (it is not), and §9.1's "references live under their owning entry skill" needs an exception for utilities belonging to no ceremony.

Retires #113 and #114 for the handoff path by construction — v2 has a minimal flag surface and does no template rendering at all. #114 stays independently open (`sd_render_template` also serves specs and retros); #115 is unrelated.

### 6.2 Owed to Plan C from the final review
- **`oss state_restore`** — replay detects drift and computes the recovered state, then discards it. The drift message is now honest about this (`a53d034`) but no restore verb exists. §9.2 binds "corruption recovery = replay from last good snapshot"; only the comparator half is built. Take the lock; write through the existing temp+rename path; **do not** write from inside `oss_state_replay` (deliberately lock-free so doctor can call it freely).
- **SKILL.md bash-block extraction harness** (§3.3) — scope explicitly.
- **`oss get` has no explicit state-file argument**, so `plan-release`'s bones-count pre-flight probe can be hijacked by a stale exported `$OSS_STATE_FILE`. Not closable at the prose layer; needs either the argument or a manifest-only resolver mode.
- Remaining untested wrappers (`spine_list`, `feature_list`, `ledger_quarantine`, …) — test them where Plan C's close actually drives them.
- `test-concurrency.sh` is sequential despite its name — real process racing only becomes reachable when parallel spine execution exists.

### 6.3 Reserved / do-not-remove
`project.composition_root` and `project.overlay_wiring` are init'd but unused — reserved for Plan D boundary work.

### 6.4 Open externally
**Issue #116** (OPEN) — `scaffold-onboard` phantom `critiquing-spec` parameter grammar, live in 3 files. Needs a `plugin.json` bump or `/plugin update` won't deliver the fix. **Separate branch — not Plan C scope.**

---

## 7. References (dispatchable index — cite, don't paste)

- `ossify/lib/state.sh` — mint-inside-lock, atomic write, journal, replay, schema guard (now gated on the write path, **before** the lock)
- `ossify/lib/commands.sh` — 26 `oss_cmd_*` wrappers; the dispatcher contract skills shell out to
- `ossify/tests/test-spine-planning.sh:85-93` — the **negative-capability** test idiom: asserts the lib *accepts* four inspector-shaped lines, pinning the prefix-only gap as a fact
- `ossify/tests/eval/` — RUNBOOK, `lib/aggregate-scores.sh` (fails closed on unparseable JSON), 5 rubrics, 23 fixtures, results
- Workflow scripts (re-runnable as-is): `…/workflows/scripts/ossify-eval-all-surfaces-wf_38136b3d-19e.js` (23 fixtures, contamination-guarded), `…/ossify-final-whole-branch-review-wf_37f704a5-6d4.js`
- Commits worth reading as exemplars: `a53d034` (final-review fix round), `e66ed1a` (fail-closed realized in state), `6abc54e` (cross-skill contract break)

---

## 8. Next intended action(s)

1. **Read §0, then `.superpowers/sdd/progress.md` end-to-end.** Confirm HEAD is `7342584` and the only dirty path is `README.md` (the user's own edit, untouched since 07-11).
2. **Decide §6.1** (amendment timing) — this is a design decision for Plan C's design section, not an implementer's brief.
3. **Detail Plan C** via `superpowers:writing-plans`, scope spec §6–§8, reusing Plan B's Global Constraints block verbatim and folding in §6.2's owed items. Non-negotiables: complete code in every step, bite-sized TDD steps, Global Constraints at top, series map for D, self-review before executing.
4. **Adversarially self-review the plan** (2 opposing-bias reviewers via Workflow) before executing — Plan B's caught 1 CRITICAL + 3 IMPORTANT *before* a line was written.
5. **Start a FRESH `.superpowers/sdd/progress.md` ledger for Plan C**, marking the Plan B ledger superseded.
6. Then execute subagent-driven per §4.

---

## 9. Suggested skills / plugins

Advisory — verify applicability before invoking.

`superpowers:writing-plans` (step 3) · `superpowers:subagent-driven-development` (step 6) · `architect-critic:critiquing-spec` with `--close` for the plan's design review · `ai-mentor:grill-me` if §6.1's decision needs stress-testing · `superpowers:finishing-a-development-branch` at Plan C close · `Workflow` for the adversarial plan review and every eval run.

**architect-critic invocation — the only supported form:** `export ARCHITECT_CRITIC_ARGS="--spec \"<abs path>\" --close"` then a bare, plugin-qualified `Skill(architect-critic:critiquing-spec)`. There is no `target=` / `depth=` / `artifact_path=` parameter; both failure modes are silent. Do **not** copy the pattern from `scaffold-onboard` — see issue #116.

---

## 10. Anti-actions

- **Do NOT re-dispatch any Plan A or B task.** The ledger is authoritative; trust it and `git log` over recollection.
- **Do NOT register ossify in `marketplace.json` or add a `.codex-plugin` manifest.** That is Plan D's ship gate and it is gated on the consolidated eval suite. Early registration also breaks `tests/test-codex-dual-publish.sh` (needs a `V0_PLUGINS` entry + Codex manifest).
- **Do NOT `git clean -fdx`** — it destroys `.superpowers/sdd/progress.md`, the recovery map.
- **Do NOT touch `README.md`** — user's own uncommitted edit, dated 07-11.
- **Do NOT edit eval fixtures or rubrics to make a skill pass.** They are the spec; fix the skill.
- **Do NOT let the invoke agent see fixture frontmatter** — it is the answer key (§3.8).
- **Do NOT settle §6.1 by default** — it is a decision, not an inheritance.
- **Do NOT read subagent output files** at `/private/tmp/.../tasks/*.output` via shell — they are full JSONL transcripts and will overflow context. Use the returned result or the workflow `journal.jsonl`.
- **Do NOT trust `resumeFromRunId` after a degraded run** (§3.11).

---

## 11. Repo operational notes

- **Git ops:** the agent does all of them (commit/merge/push/tag). The auto-mode classifier still blocks `gh pr merge` and direct `git push origin main` until explicit in-turn authorization.
- **No commit-msg hook** in this marketplace repo, so the `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` trailer is fine here. (workspace-init-paired consumer projects *do* block it — different context.)
- **Commit scope:** always explicit paths (`git add ossify/… docs/…`) — **never** `git add -A`. Unrelated files live in the tree.
- **Test commands:** `bash ossify/tests/run-all.sh` · `for t in tests/test-*.sh; do bash "$t" || echo "ROOT-FAIL: $t"; done` · `bash ossify/tests/eval/lib/aggregate-scores.sh`.
- **Skill-listing budget (measured 2026-07-26):** ossify's 3 entry skills = 2,474 chars ≈ 619 est. tokens = **0.31% of a 200k window**, vs the scaffold pair + workspace-init at 1.63%. §9.1's target is verified. Quote the window with the percentage — on the 1M model in use the same listing is 0.76%.

---

## 12. North star

ossify exists because scaffold-dev's completed sprints never yielded usable software — pulse-trader's first tradeable UI was 7 sprints deep *by spec design*, and roughly half its "vertical slices" were horizontal component builds (VS-1.1.4's user demo was literally *"inspect the SQLite schema"*). Every Plan C skill should be judged on: **does it get the user to a usable product faster, and does it make "the product still runs" a checked fact rather than an assumption?**

Plan C owns the half that makes that check real. Plan B authored the demo *criteria*; Plan C builds the ceremony that *runs* them.

---

## 13. Return-handoff stub

**Summary:** _(what Plan C accomplished against §8)_
**Deferrals:** _(what moved to Plan D)_
**Cautions:** _(what the next session should be careful of)_
**Memory-bank promotion candidates:** _(from Plan C's §3-equivalent)_
