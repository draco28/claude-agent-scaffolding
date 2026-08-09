# Startup Prompt: ossify v0.2.0 — absorb the audit, plan the release

> Copy everything below the line into a fresh session.

---

Read `docs/superpowers/handoffs/2026-08-09-ossify-v01-to-v02.md` and proceed.

Run §5 step 1 first and reconcile before trusting anything in it — including the
assertion count, which should be **981**, and the tag, which should now resolve onto
`main`. Do not copy a base commit out of the handoff, the roadmap, or any other
document; read it from `git log` at the moment you need it. Three handoffs in this
series recorded a hash that was stale before it was read.

## What this session is for

ossify v0.1.0 shipped (PR #117, tagged, merged). The engine is complete and green.
Two planning artifacts arrived *after* the C1 branch review and **neither has been
reconciled against the roadmap**:

- `docs/superpowers/reviews/2026-08-09-ossify-skill-audit.md` — a quality audit,
  ~80 findings in six batches A–F with a dependency graph
- `docs/superpowers/specs/2026-08-09-ossify-capability-gap-absorption.md` — 7 new
  capability reference docs, from a comparison against `obra/superpowers` and
  `mattpocock/skills`

The deliverable is a **written v0.2.0 plan**. Not code.

## Three things to settle before you plan

**1. Confirm the audit's scope.** Its header scopes it to `ossify/` only. Droid's
wider review covered the other plugins too, but no all-plugins report exists on disk,
on any branch, or in any stash — I searched. Establish whether that half was ever
written out before planning from the half that was.

**2. Verify the roadmap's strikethroughs.** It records four majors as resolved inside
PR #117 by a Droid review round, taking the list from 7 to 2. I confirmed those fixes
exist in `a5d61f1`'s diffstat but **did not test that each one closes the finding it
claims**. Re-run the four reproductions from
`docs/superpowers/reviews/2026-08-05-plan-c1-branch-review.md` against `main` first.
If any is still live, the v0.2 scope grows.

**3. Do not merge the two backlogs blindly.** The audit deliberately does not
re-report the C1 correctness findings and carries a "C1-findings subsumption map"
naming seven it absorbs. Dedupe through that map or you will plan several items twice.

## What v0.2.0 has to contain

Its **blocking** item is an **entry point for the execution lane**. Right now nothing
routes a user into `round-orchestration.md` — no skill description matches "run the
rounds" or "execute the spine". The engine C1 shipped is unreachable. Bundle audit
findings WI-3 through WI-6 into that same task: making the lane reachable without
fixing its content gaps ships something that works and misleads.

Then: the 2 remaining majors, the filed dispatcher defects (`task_cab0ee8c`), 13 minors
+ 3 nits, dispositions for the two zero-consumer verbs (`oss worktree_list`,
`oss manifest_get`), and the 2 capability references the roadmap already absorbed into
this release (`debugging.md` under `work-item`, `code-review.md` under `close`).

Batch B is blocked on four design mini-decisions — the ADR directory/numbering
convention, whether feature-map rank/prune need verbs or stay conversational, the
patch-lane target-branch rule, and whether to expose `oss release_dir`. These are
judgment calls; a brainstorm or grill-me pass fits better than a dispatch.

## Discipline this series paid for

- **Run the pre-dispatch plan sweep before briefing any task.** It found a defect in
  **14 of 14** C1 tasks. Verify the task's literal code, file lists, line numbers and
  cross-task claims against the tree, correct the plan, commit the correction, *then*
  brief.
- **A correction is new code.** Five of my fourteen corrections introduced a defect of
  their own. The nastiest form is prose-right/command-wrong — the sentence says the
  right thing while the command computes something else (`git diff A..B` is not a
  range; a payload key gets renamed by the apply-op). **Run every git/shell/jq idiom
  you write into a plan. Do not reason about it.**
- **A wrong-target git operation succeeds at rc 0.** Three P0s this series were merges
  landing on the wrong branch with every rc check green. Assert a concrete observable —
  a sha's reachability, a branch name, a file in a tree — never rc alone.
- **Five ways a test here has been found unable to fail:** the verifier re-derives its
  expected value from what the code just wrote; the fixture never trips the guard's
  precondition; the harness supplies the property (`t_capture` forks a subshell); the
  mutation never applied; fixtures coupled through shared state. Only mutation finds
  them — and **echo the mutated line back**, because a no-op `sed` and a worthless test
  look identical from the pass count.
- **Tag after the merge, not before.** This repo squash-merges, so a tag cut on the
  branch lands off `main`'s history. v0.1.0 had to be retagged for exactly this.

## Sequencing constraint worth holding from the start

**Batch E (bloat / token budget) must land before `doctor` ships in v0.3.** The sixth
entry-skill description pushes past the §9.1 budget band. C1 already had to trim five
descriptions from 4,180 → 3,121 characters (0.52% → 0.39% of a 200k window) to get
inside the target. There is very little headroom left.

opus for this one — it is planning and judgment, and the prose is eval-gated.
