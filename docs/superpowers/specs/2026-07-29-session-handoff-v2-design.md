# Session Handoff v2 — Generic, Gate-Free, Repo-Adaptive

**Date:** 2026-07-29
**Status:** DESIGNED — awaiting user review, then implementation planning
**Origin:** Brainstorm session 2026-07-29, prompted by live friction authoring a plan-to-plan handoff in a repo with no pairing manifest
**Home:** ossify — planned and built during **Plan C**, as a generic utility that is not coupled to ossify's own lifecycle
**Supersedes:** `scaffold-dev/skills/handing-off-session` (maintenance mode) for all new work

---

## 1. Problem & evidence

Session handoff is the mechanism for continuing work in a fresh context. It is the one capability that should work **everywhere** — any repo, any stack, any methodology, or none. Today's implementation works in exactly one topology and refuses everywhere else.

**Evidence, gathered 2026-07-29 against `scaffold-dev` 0.18.0:**

- **Hard refusal without a pairing manifest.** `sd_handoff_dir()` (`lib/handoff.sh:26-30`) calls `sd_manifest_get '.ai_workspace.root'` and returns non-zero when absent. Every path function chains off it, so no manifest means no path, no id, no write. `skills/handing-off-session/SKILL.md:66,75` makes this a verbatim refusal. Reproduced live: this marketplace repo has no `.workspace/pairing.json` anywhere on the walk-up, and the skill refused durable mode outright.
- **The coupling is four layers deep, not one check.**
  1. *Storage* — anchored at `<ai_workspace.root>/.workspace/handoffs/`.
  2. *Vocabulary* — the scope enum is `sprint | slice | mid-slice | bugfix | techdebt` (`lib/handoff.sh:6`). A plan-to-plan handoff fits none of them.
  3. *Template contract* — `templates/handoff.md.tmpl:10` defines `state_pointers_block` as "workspace paths, sprint/slice IDs, worktrees, branches". Dual-repo and slice concepts are baked into the section definitions.
  4. *Lifecycle* — `sd_handoff_cleanup_sprint()` ties retention to sprint boundaries. A repo without sprints has no retention story.
- **Three open bugs in the same subsystem**, all filed 2026-07-12 from live PulseTrader VS-1.3.2 use and tagged by the reporter as one "input-handling fragility class": **#113** (`sd_handoff_parse_flags` truncates multi-word flag values to the first token — `--purpose` is almost always a sentence), **#114** (`sd_render_template` truncates multi-line variables to the first line — and *every* `{{…_block}}` in the handoff template is multi-line), **#115** (`sd_harvest_apply` returns `rc=0` and writes nothing).
- **The gitignored-storage failure is total, not partial.** scaffold-dev writes handoffs to a gitignored path, so they do not survive a machine change and are invisible to collaborators. This repo commits them under `docs/superpowers/handoffs/` — which is the only reason the 2026-07-13 Plan A→B handoff survived to reconstruct a session whose originating context had become unresumable.

**Consequence:** the capability meant to make work portable across contexts is itself the least portable thing in the toolchain.

## 2. Design goals

1. **Works anywhere.** Any repo shape, any methodology, or no methodology. Never refuses for structural reasons.
2. **No deterministic gates.** Nothing in the runtime path blocks, validates, or rejects. Quality comes from taught judgment plus build-time evals, not from refusals.
3. **Adapts rather than assumes.** Location, naming, and tracked-vs-ignored are judged from the repo in front of the agent.
4. **References, not copies.** The handoff is an index into the project's existing memory, not a duplicate of it.
5. **Resumable and verifiable.** A fresh session can confirm the handoff is still true before acting on it.
6. **Cheap.** Zero every-call listing cost; no new entry skill.

## 3. Decisions

| # | Decision |
|---|---|
| 1 | Lives in **ossify**, planned during **Plan C**, but built generic — not bound to ossify's release/spine lifecycle |
| 2 | **No deterministic gates.** No manifest refusal, no scope enum, no filename regex, no section-count invariant, no non-empty refusals, no gitignore exit-check |
| 3 | **Small fixed core of sections** (6), extended freely by the agent per project |
| 4 | **Location judged from repo evidence**, stated in one line; never asked, never configured |
| 5 | Quality via **non-blocking read-out at runtime + eval surfaces at build time** |
| 6 | **Two modes: compose and resume.** Resume re-verifies the handoff's claims against the live repo before work begins |
| 7 | **Forward/return chain model dropped.** With it go short-ids, the filename regex, and the scope prefix |
| 8 | **Pure skill — no new lib code.** No `oss handoff_*` subcommands |

## 4. Architecture & ownership

```
ossify/commands/handoff.md            compose
ossify/commands/handoff-resume.md     resume
ossify/references/handoff/
  compose.md                          how to judge and write one
  resume.md                           how to ingest and re-verify one
  sections.md                         the core template + adaptation guidance
```

**No new entry skill.** ossify §9.1 caps front-loaded entry skills at ~6 and they are allocated (`start`, `plan-release`, `plan-spine`, `close`, `work-item`, `doctor`). The command wrappers are the entry point; they instruct the agent to read the relevant reference. Measured 2026-07-26, ossify's three shipped entry skills cost 2,474 chars ≈ 619 est. tokens ≈ **0.31% of a 200k window**; this design adds **zero** to that, because references cost nothing until loaded.

**References at plugin root, not under an entry skill** — a deliberate deviation from §9.1's "references live under their owning entry skill", for two reasons. *Mechanically*, references under `doctor` would load whenever `doctor` loads, and handoff has nothing to do with state inspection. *Semantically*, handoff belongs to no lifecycle stage — filing it under `close` would imply handoffs happen at close, when in practice they are written mid-work as context runs out. A plugin-root location says "this belongs to no ceremony", which is what makes it generic.

**Naming:** `<date>-<topic>.md`. No ids, no scope prefix, no regex.

## 5. The core sections

Six, collapsed from v1's twelve. Every removal is a merge or a consequence of dropping the chain model.

| # | Section | Carries | Replaces (v1) |
|---|---|---|---|
| 1 | **Orientation** | What this handoff is for; the one thing to do first | Header + Purpose + focus field |
| 2 | **State** | Where the work is — as checkable claims | State pointers + In-flight state |
| 3 | **Uncodified context** | What is true but written nowhere else | "What's NOT in memory bank yet" |
| 4 | **References** | Pointers to what already holds the detail | Must-read + References |
| 5 | **Next actions, in sequence** | Ordered, concrete, with what "done" looks like | Next intended action(s) |
| 6 | **Traps** | What not to do; assumptions now invalid | Anti-actions + Workflow deviations |

`Suggested skills` folds into §5 — it was always advice about *how* to do the next action. `Return-handoff template stub` disappears with the chain model.

**§3 gets a methodology-neutral name.** "What's NOT in memory bank yet" presumes a memory bank. "Uncodified context" asks the same question of any project: *what do you know that no file knows?* — decisions made in conversation, approaches rejected and why, half-formed hypotheses, surprises.

**§2 is written as checkable claims.** Not "tests were passing" but `suite green at 7342584 — bash ossify/tests/run-all.sh`. Not "the branch is ahead" but `40 ahead of main, 0 behind, as of 2026-07-28`. Every claim carries an as-of and a way to check it; anything the writer could not verify is marked rather than asserted. **This is the contract between compose and resume** — if §2 is vague prose there is nothing for a fresh session to re-verify, and resume mode becomes decorative.

**Extension by project shape**, taught by example rather than enum: an active tracker adds *Open issues touched*; a migration adds *Rollback state*; a research spike adds *Hypotheses tested and rejected*. The six are a floor, not a ceiling.

## 6. Compose mode

**Location, judged from evidence** — in rough priority: does the repo already contain handoffs anywhere (strongest signal: match their directory, naming, *and* tracked/ignored status); is there a `docs/` tree; what does `.gitignore` say about docs of this class; is this a monorepo where the work is scoped to one package; is it a git repo at all. The agent picks and states where and why in one line.

**Tracked vs gitignored is a first-class decision.** A handoff that cannot be retrieved from another machine is a handoff you do not have. Default is to follow the repo's precedent; absent precedent, prefer tracked, because the failure mode of an uncommitted handoff is total. Whichever is chosen, it is stated.

**Committing** follows the same precedent: where the repo tracks handoffs, the ceremony includes the commit and says so; where precedent is untracked, write and leave it. Never silent either way.

**Reference-over-duplication, with a test.** Before anything enters §3, ask: *does a file already hold this?* If yes it belongs in §4 as a pointer with a one-line "what's here" — path, SHA, or URL, never pasted content. This keeps handoffs from bloating into transcripts and lets a receiving session dispatch a subagent straight at a reference.

**The read-out**, stated in conversation before writing, blocking nothing:

```
Handoff read-out — <topic>
  Location   <path>  (<why: precedent | docs tree | fallback>)   tracked: yes/no
  §2 State   <n> claims, each with an as-of and a way to check it
  §3 Value   <one line: what's here that no file holds>
  §4 Refs    <n> pointers — nothing pasted that a path could carry
  §5 Order   <n> steps; step 1 is <x>
  Weakest    <the thinnest part, named honestly>
```

`Weakest` is the field doing the real work. v1 tried to guarantee quality by refusing to write; v2 surfaces the weak spot and lets a human look at it. A thin §3 on a genuinely trivial handoff is correct; a thin §3 nobody noticed is not.

## 7. Resume mode

Invoked as `/handoff-resume <path>`, or with no argument to take the most recent handoff found by the same evidence logic compose uses.

**Verify before trusting, cheaply.** §2's claims were written as checkable assertions precisely so this is mechanical — resolve the recorded commit, compare branch, re-run the named suite command where one is given, existence-check cited paths. Seconds of `git` and `test -e`, not a re-read of the project.

**References are verified for existence, not contents.** Resume confirms a cited path still exists, then reads it only if and when a step in §5 needs it. Front-loading every reference would reproduce the context bloat the handoff exists to avoid.

**The drift report**, before any work begins:

```
Resume read-out — <path>   (written <date>, <n> days ago)
  §2 claims   <n> checked · <n> hold · <n> DRIFTED
     DRIFT    HEAD was <x> → now <y> (<n> commits since)
  §4 refs     <n> resolve · <n> missing
  §5 step 1   <still applicable | superseded by drift>
  Verdict     <proceed | proceed with adjustments | stale — re-plan before acting>
```

**Drift reports; it never refuses.** A drifted claim is information — sometimes the drift *is* the expected progress. The verdict is a recommendation the agent states and the user can override.

**Age is surfaced, not gated.** §3 is unverifiable by construction. What resume can do is show its age, so a three-week-old "we decided X" is read with appropriate suspicion.

Resume then follows §5's sequence — which is what makes the ordering executable rather than advisory, against a state just confirmed.

## 8. Failure behaviour

**One rule: degrade and report, never refuse.**

| Situation | Behaviour |
|---|---|
| Not a git repo | Write to cwd, say so |
| No precedent, no `docs/` tree | Repo root, say so |
| Ambiguous location | Pick, state the reasoning in one line |
| Resume target not found | List the candidates found |
| Cited reference missing | Report as drift, continue |
| `.gitignore` absent or unclear | State the tracked/untracked choice made and why |

Every one of these is a case where v1 either hard-refuses or silently proceeds. Neither is acceptable; the replacement is identical in all cases — judge, state in one line, continue.

## 9. Eval surfaces

Two, following ossify's established pattern (fixture **body only** to an invoke agent, frontmatter answer key to a judge, run as a Workflow by the controller).

**`handoff-compose`** — 5 fixtures. Criteria: `location_correct`, `tracked_decision_stated`, `references_not_duplicated`, `claims_checkable`, `sequence_ordered`, `weakness_surfaced`.

1. Repo with existing **committed** handoffs → matches precedent, tracked
2. Repo with existing **gitignored** handoffs → matches precedent, states the survivability tradeoff
3. No precedent, `docs/` tree present → picks it, tracked, states why
4. Content that already lives in a spec → pointer in §4, **not** pasted into §3
5. **Negative control** — a genuinely trivial handoff where a lean §3 is *correct*

Fixture 5 is what the surface lives or dies on. Per the B5 review lesson, a surface where every fixture rejects cannot distinguish rigor from indiscriminate paranoia — a skill that flagged every handoff as thin would pass a control-free suite. Distinguishing *appropriately lean* from *lazy* is the only interesting judgment in compose mode.

**`handoff-resume`** — 3 fixtures. Criteria: `drift_detected`, `no_false_drift`, `missing_reference_reported`.

1. Handoff whose claims no longer hold → catches them; verdict reflects it
2. **Negative control** — handoff still fully accurate → proceeds clean, invents no drift
3. Cited path deleted → reported as drift, not treated as fatal

**Two disciplines carried from Plan B:**

- **No fixture wording in the skill prose.** The invoke agent reads the references; leaving fixture examples in them turns the eval into a recall test. B8's implementer stripped and re-domained its examples deliberately, raising its own miss probability, and the surface still passed.
- **Fixtures are the spec.** When a fixture and the prose disagree, the prose changes.

Together this takes ossify's eval gate from 23 to **31 fixtures** across 7 surfaces.

## 10. Spec amendments required

| Spec | Section | Change |
|---|---|---|
| `2026-07-11-poc-first-lifecycle-design.md` | §8.1 catalog | `handing-off-session` row reads "**Unchanged** — utility command `/handoff`". It is not unchanged; becomes "**Re-anchored** — generic, methodology-agnostic; see the handoff-v2 design" |
| same | §9.1 | "references live under their owning entry skill" gains an exception for utilities belonging to no ceremony |

## 11. Scope fence

**In:** the two command wrappers, three reference docs, the six-section core, compose-mode location/tracking judgment, the read-out, resume-mode verification and drift report, failure behaviour, both eval surfaces, the two spec amendments.

**Out:** forward/return chaining (dropped; additive later if it earns its keep); handoff retention/cleanup policy (no sprint model to hang it on — handoffs accumulate and the user prunes); porting the other scaffold-dev utilities (`/defer`, `/adr`, …) — this design covers handoff only; fixing `scaffold-dev`'s v1 in place (maintenance mode; superseded).

## 12. Open questions (non-blocking)

1. **Command naming.** `/handoff-resume` vs `/resume` — the latter is shorter but collides conceptually with Claude Code's own session-resume. Settle at implementation planning.
2. **Multi-handoff repos.** When several handoffs exist, resume-with-no-argument takes the most recent by filename date. Whether that should prefer the most recent *matching the current branch* is worth revisiting once there is usage.
3. **Relationship to ossify's `close`.** The close ceremony should probably offer `/handoff` at sprint/release boundaries, as v1's checklist did. Wiring is Plan C's call.

## 13. Relationship to existing issues

**#113** (`sd_handoff_parse_flags` truncation) and **#114** (`sd_render_template` multi-line truncation) are bugs in machinery this design **removes** for the handoff path: v2 has a minimal flag surface and no template rendering at all — the agent authors the document directly. Neither bug can recur in v2. #114 remains independently valid because `sd_render_template` also serves specs and retrospectives, which are outside this design's scope.

**#115** (`sd_harvest_apply` silent no-op) is unrelated to handoff and stays an independent bug.

**#113 is the tracking issue for this design** — it is handoff-specific, open, and its reported symptom is one of the failures v2 retires.
