# Dogfood — recommend-by-default decision policy (#93), first live exercise

**Date:** 2026-07-02 · **Session:** post-#93 dogfood · **Fixture:** the #38/#37/#10 "reconsider-first" backlog decision · **Depth:** dialogue + critique

## Why

#93 shipped a recommend-by-default policy across four decision-surfacing skills (ai-mentor `grill-me` + `council`, architect-critic `critiquing-spec`, scaffold-dev `orchestrate`) but had never been run for real. This exercise ran the skills live on a genuine decision to prove the shipped contract holds and to surface any defect in the shipped SKILL.md instructions. Contract SoT: `docs/conventions/recommendation-policy.md`.

## What was exercised

| Surface | Run | Result |
|---|---|---|
| Parity precondition | `tests/test-recommendation-policy-parity.sh` | ✅ `Passed: 7 Failed: 0` (3 copies byte-identical to SoT) |
| `council` (Chairman synthesis, default-on) | build/cherry-pick/wontfix on #38/#37/#10 | ✅ conforms — 5 voices in fixed order, `## Chairman's synthesis (recommended)` with one firm **cited** verdict per issue + accept/rebut/defer invite |
| `critiquing-spec` (shallow / author-depth) | audit of the decision doc | ✅ conforms — challenge cards carry cited `Recommended: <disposition>`; disposition engine + defer-tracking exercised |
| `--neutral` suppression + non-stickiness | on the `/critique` surface | ✅ `Recommended:` line omitted under `--neutral`; per-invocation, not sticky |
| `grill-me` / `orchestrate` | NOT run | grill-me blocked by council composition rule (see F4); orchestrate has no active slice — **untested surfaces** |

All conformance independently re-verified by a fresh-eyes subagent; all six council citations RESOLVE exactly with zero drift.

## Verdict on the policy

**Recommend-by-default held on every exercised surface.** The single most important validation: **the recommendation did not railroad the user.** Council recommended cherry-pick-redaction-only for #38; the user rebutted with felt-pain evidence and chose build-all-5, and expanded #37 from 1 leg to 2. That is Rule 5 (user is final authority; a recommendation is a lean, never an auto-advance) demonstrated live, not just asserted in prose. Citations stayed traceable and were never fabricated (subagent-verified).

## Findings

- **F1 — real bug (correctness).** `architect-critic/skills/critiquing-spec/SKILL.md` Step 8 (L389) prescribes `arc scorer_score "$CHALLENGE_TEXT" "$REBUTTAL_TEXT"`. **That dispatcher function does not exist** → `Unknown function: ac_scorer_score` (exit 2). The real function is `scorer_score_rebuttal`. Every rebuttal path fails exactly as written. Worsened by `bin/arc`'s own header comment (L23) advertising the phantom `scorer_score`. → **filed as #96.**
- **F2 — SKILL/lib vocabulary divergence.** `lib/scorer.sh:scorer_decide` maps ≤3→`restate`, ≥4→`concede`; the SKILL rubric (L391-392) says ≤3→"challenge **stands**." Different third-outcome semantics, and `scorer_decide` is never wired into the SKILL's prose rubric path at all. → fold into the F1 fix (scorer wiring is out of sync).
- **F3 — tension with a promoted principle (interpretive).** `scorer_score_rebuttal` is a deterministic (lexical) gate that scored a material-new-info rebuttal a **3** — the exact "deterministic semantic-quality judgment" that user-promoted principle `pp-e72993dfb626c518` says belongs to an agent reviewer. The *fact* (score 3) is execution-verified; the *interpretation* is a judgment. → consider replacing the scorer's semantic call with agent judgment (the SKILL already mediates the score inline; the helper may be dead weight).
- **F4 — composition friction (plan assumption invalidated).** The plan assumed grill-me was the cheapest `--neutral` probe, but `council/SKILL.md:55` forbids running grill-me in the same session as council. Rerouted the probe onto `/critique`. Council/grill-me neutral paths were inspection-verified (council L26, grill-me L30), not executed.

## Untested surfaces (honest coverage gaps)

- `orchestrate` 5-gate path + nested `--neutral` forwarding — not exercised (no active vertical slice).
- `grill-me` recommend-by-default rendering — inspection-verified only (composition rule).
- `critiquing-spec` **close-depth** (Codex fresh-frame) + async — not exercised (author-depth only).

## Decision outcome (see reconsideration-decision-38-37-10-FINAL)

#38 → build all 5 legs · #37 → build legs 2+3, wontfix 1/4/5 · #10 → wontfix (trigger recorded).
