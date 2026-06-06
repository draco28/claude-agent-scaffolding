# Session handoff — Program state after SS-2 shipped · what's next

**Date:** 2026-06-06 · **Author:** closing session (SS-2 closeout) · **Purpose:** forward handoff for a fresh session to pick the next sub-spec and resolve where #56 belongs.

---

## 1. Where the program stands

`main` @ `d204729` (clean except untracked `.claude/`). Plugin versions on main:

| Plugin | Version |
|---|---|
| workspace-init | 0.1.2 |
| scaffold-onboard | **0.5.0** (SS-2) |
| scaffold-dev | 0.3.0 |
| architect-critic | 0.2.2 |
| ai-mentor | 2.0.0 |
| claude-security-audit | 0.1.2 |

**Agent-driven program** (`docs/agent-driven-program/SPEC-agent-driven-program.md`) sub-spec status:

| Sub-spec | Scope | Status |
|---|---|---|
| **SS-1** | Memory-bank ownership + single-point cadence (#45) | ✅ SHIPPED 2026-06-04 (PR #54, `scaffold-onboard-v0.4.0` + `scaffold-dev-v0.3.0`) |
| **SS-2** | Synthesis live & verified + EXEC-SUMMARY + derivation-reviewer (#50/#49/#42) | ✅ SHIPPED 2026-06-05 (PR #55, `scaffold-onboard-v0.5.0`) |
| **SS-3** | Agent-synthesized, resumable onboarding (#51) | design-only; **not started** · parallel-eligible after SS-1 |
| **SS-4** | Agent-review of the verification seams (#7, #5, #48 C–F partial) | design-only; **not started** · independent |
| **SS-5** | Codex implementer/synthesizer backend (#47) | design-only; **not started** · independent |
| **SS-6** | Standalone cleanup to zero (#8, #9, #6, #10, #37, #38, #39 + routing/label) | design-only; **not started** · interleave |

The program's north star: **agent-driven derivation is first-class; mechanical/bash only for non-reasoning facts.** Goal = drive the GitHub backlog to **0 open issues** (§6 ledger).

---

## 2. The #56 question (resolve this FIRST next session)

**What #56 is:** "Remove the deterministic `--fast` fallback (agent-driven only) across scaffold-onboard." It came out of SS-2: the user committed (2026-06-05, explicit) to **no deterministic fallback anywhere** — when the LLM can't generate (token cost, etc.), wait/retry the agent rather than fall back to deterministic templates. This is the logical endpoint of the agent-driven-first-class pivot ([[project_agent_driven_first_class_pivot]]).

**Why it exists as a separate item:** during SS-2, Codex flagged that the `--fast` deterministic path doesn't honor manifest routing (memory-bank §13.2, governance §11.2 split `product_adrs`→canonical / `process_adrs`→ai_workspace). We deliberately **did not fix** that — polishing a path slated for deletion is wasted effort — and filed #56 instead. SS-2 only routed the **keep-forever** steps (live-file seed + SS-1 harvest migration) to the manifest destination.

**The gap the user spotted (correct):** #56 is currently only a **ledger row (N6)** in `SPEC-agent-driven-program.md` §6, mapped loosely to "SS-3+ (own sub-spec)". It is **NOT** a formal sub-spec section like SS-3..SS-6. So step 1 next session: **slot it into the sub-spec plan.**

**Recommendation (for the fresh session to confirm, ideally via `/brainstorm` or `ai-mentor:grill-me`):**
- **Option A — new dedicated SS-7 "Remove deterministic fallback (agent-driven only)".** Cleanest given its breadth: it spans memory-bank + governance + (per the user's broader vision) eventually onboarding/MASTER-SPEC + roadmap. Removing the deterministic engine (`SF_SYNTH_FAST`/`sf_synth_mode` fast branch, `--fast` command surface, the per-artifact deterministic fallback) is a large change with its own regression surface (the deterministic path is widely tested). Recommended.
- **Option B — fold into a reframed SS-3.** SS-3 is the "agent-synthesis" sub-spec; the user's vision ("remove ALL determinism across onboarding, roadmap, docs, memory-bank") overlaps SS-3's territory. Could merge into one broader "agent-driven-only" sub-spec. Risk: SS-3 balloons.

Either way: this needs a design pass before building (it's not a quick fix). Add the chosen section to `SPEC-agent-driven-program.md` §5 and update the N6 ledger mapping.

---

## 3. Next-session options (pick per SPEC §5 sequencing)

1. **Resolve #56 placement** (§2 above) — do this first regardless, it's a 10-min ledger/SPEC edit + a design decision.
2. **SS-3 (#51) — agent-synthesized resumable onboarding.** MASTER-SPEC is currently mechanical transcription (`sf_master_spec_update_phase` substitutes raw answers into `{{phase_X}}` slots). SS-3 moves to: phased-discussion scratch file (resumable) → agent-synthesize MASTER-SPEC + EXEC-SUMMARY via a tool-agnostic prompt → delete scratch. **OQ-3 still open** (scratch-file format/location/lifecycle). Natural next given SS-1/SS-2 done and it's the same agent-driven theme. Needs a sub-spec (design-lock) before build.
3. **#56 / SS-7 — remove deterministic fallback.** Big agent-driven-purity lever; aligns with the user's strongest stated direction. Could be done before or after SS-3 (they're related — sequencing is a design call).
4. **SS-6 — knock out independent cleanup issues** (#8 ban git stash, #9 Scenario C pairing, #6 ADR flip, #10 parallel slices, #37/#38/#39, #52, #53 CI). Good "burn down the backlog" option; many are small and independent. #53 (no CI) is worth early attention — there's no `.github/workflows` running the shell suites, so all verification is local-only.
5. **SS-4 / SS-5** — verification seams / Codex backend; independent, lower urgency.

**Suggested:** start the fresh session by re-reading `SPEC-agent-driven-program.md` (§5 sequence + §6 ledger), resolve #56's placement, then brainstorm whichever of SS-3 / SS-7 the user wants to build next.

---

## 4. Open backlog (15 issues → target 0)

`#5 #6 #7 #8 #9 #10 #37 #38 #39 #47 #48 #51 #52 #53 #56`

Mapped in `SPEC-agent-driven-program.md` §6. (#42/#49/#50 closed by SS-2; #45 by SS-1.)

---

## 5. Process notes for the next session

- **Build method:** `superpowers:subagent-driven-development` against a design-locked sub-spec plan (implementer + two-stage spec/quality review per work item) — worked well for SS-1 and SS-2.
- **Verification discipline (load-bearing):** re-run the WHOLE suite yourself; don't trust "passed" claims ([[feedback_full_suite_when_verifying_subagents]]). SS-2 reinforced [[feedback_test_upgrade_input_class]] hard — an **adversarial correctness review** caught a MASTER-SPEC write-back that would silently corrupt the source-of-truth, which every green test missed. Run an adversarial review on any new source-of-truth-mutating behavior.
- **Bot review:** Codex does NOT auto-trigger on push — comment `@codex review`; its **clean verdict posts as an issue-comment** ("Didn't find any major issues"), while findings post as a **review object** — poll BOTH. Codex has per-window usage limits. CodeRabbit auto-runs.
- **Handoff skill caveat:** `scaffold-dev:handoff` / `handing-off-session` refuse in this plugin-source repo (no `.workspace/pairing.json`). Manual handoffs live here: `docs/agent-driven-program/handoffs/*.md` (this file).
- **`.claude/` stays untracked** — never `git add` it.
- Suites are slow (55–75s+/file; full scaffold-onboard ~12–15 min) — use generous timeouts, background + wait.

---

## 6. Entry point for the fresh session

1. Read `docs/agent-driven-program/SPEC-agent-driven-program.md` (north star + §5 sequence + §6 ledger).
2. Decide #56's home (new SS-7 vs fold into SS-3) and update the SPEC + N6 ledger row.
3. Pick the next sub-spec to build (SS-3 or SS-7 likely) → brainstorm/design-lock a sub-spec under `specs/` → plan → `subagent-driven-development`.
