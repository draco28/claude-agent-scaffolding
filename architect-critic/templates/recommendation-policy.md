# Recommendation policy (recommend-by-default)

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
rather than adjudicate cold.

This policy governs **how** a decision is presented, never **what** is asked or
challenged. The skill's own logic decides what to surface; this policy only adds
that a grounded recommendation rides along with it.

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

4. **Explicit opt-out.** A `--neutral` flag, or a natural-language "no
   recommendations" / "just give me the options" request, **suppresses** all
   recommendations for that invocation: surfaces revert to neutral options and the
   user adjudicates cold. Opt-out is per-invocation, not sticky.

5. **The user is the final authority.** A recommendation is a lean, not a decision.
   It never auto-advances past a decision boundary, never removes a choice, and
   never overrides an explicit user direction.

## Why default-on

A neutral option dump pushes the whole adjudication cost onto the user every time.
A firm, cited recommendation lets them accept fast when they agree, and gives them
something concrete to push against when they don't — itself faster than reasoning
from a blank slate. Grounding the recommendation in the project's own
source-of-truth (rather than generic best practice) is what makes it trustworthy,
and the skills that adopt this policy already have that source-of-truth in context,
so the grounding is essentially free.

## How a skill adopts this policy

Each adopting skill's `SKILL.md` references this file and describes, in a few lines,
how the policy renders on **its** surface (a grill question, a verdict, a challenge,
a gate) and which source-of-truth it grounds against. The universal rule above does
not change per skill; only the rendering does.
