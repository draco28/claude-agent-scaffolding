# Reconsideration decision — backlog #38 / #37 / #10

**Date:** 2026-07-02 · **Author:** dogfood session (recommend-by-default policy, post-#93) · **Status:** decided (user-authoritative)

## Context

Three `deferred`+`enhancement` issues had sat "reconsider-first" across ~10 handoffs. The program North Star (`SPEC-agent-driven-program.md` §1) is a **zero open SPEC §6 ledger** where every issue is consciously **built or wontfix'd**. This decision was surfaced by `/council` (recommend-by-default Chairman synthesis) and stress-tested by `/critique`; the **user overrode the council on #38 and expanded #37** with felt-pain evidence — the recommendation was a lean, not a rail. Governing lesson: `[[feedback_reconsider_deferred_before_building]]`.

## Decisions

### #38 — handoff quality controls → **BUILD all 5 legs** (user override of council's cherry-pick-only)

Council recommended cherry-pick-redaction-only; the user rejected that — all five legs are recorded felt pain:

1. **Suggested skills/plugins section** — next-session handoffs don't reliably invoke the right skills/plugins; naming likely capabilities up front fixes that.
2. **Artifact-reference discipline** — reference specs/ADRs/**commits** by path/SHA instead of pasting content: de-bloats the handoff **and** lets the main session dispatch subagents straight at those references instead of hunting for them.
3. **Redaction pass** — grep-for-secrets/PII sweep that halts before writing (also council-accepted; safety). *Build spec must specify its own failure modes: false-pos / false-neg / hard-block-vs-warn (critique C3, deferred here).*
4. **Next-session focus field** — plain-language "what to do first," separate from the `--purpose` slug; rides along once refs de-bloat the doc.
5. **Lightweight/ephemeral handoff mode** — non-dual-repo projects and non-slice/brainstorming moments need handoffs that don't exist today; opt-in, doesn't replace the durable path.

### #37 — grill-me domain-language + ADR thresholds → **BUILD legs 2 + 3; wontfix 1, 4, 5**

- **Leg 2 — "code contradicts claim" rule → BUILD, with a mode-dependent source-of-truth (sharper than the filed issue):**
  - During **development/implementation**: **code is source of truth** — a contradicting doc gets updated to match code.
  - During **vision-aligned planning** (next slice / enhancement): **the vision/doc is source of truth** — contradicting code gets fixed.
- **Leg 3 — strict three-part ADR threshold → BUILD** (record only when hard-to-reverse **and** surprising **and** a real tradeoff). Cheap, council-accepted.
- **Leg 1 (terminology-deltas), Leg 4 (memory-bank domain map), Leg 5 (docs-as-you-decide) → wontfix** — not felt useful; revisit on real need. (Build-time: verify legs 2/3 aren't already live post-#88/#93 — critique C5.)

### #10 — coordinating-parallel-slices skill → **WONTFIX (demand-gated, no signal)**

Sole maintainer attests no current parallel-slice demand (the demand sensor is the maintainer's own need — critique C1 rebuttal, conceded). Exact analog of the #58 wontfix-over-completion precedent (commit `593db05`). **Trigger recorded (icebox-in-the-close, critique C4):** revisit only when a real multi-worktree parallel-slice job actually lands; the design thinking in the issue body is preserved by the close comment.

## Net backlog effect (revised from council's "4→1")

- **#10** closes **wontfix** now.
- **#38** stays open as a **full 5-leg build**; **#37** stays open as a **2-leg build** (legs 2+3) with 3 legs wontfix-noted.
- SPEC §6 open backlog after this session: **#85** (chore) + **#38** (build) + **#37** (partial build) = **3 active**, #10 closed. "Reaching zero" now means executing the #38/#37 builds in future sessions.
