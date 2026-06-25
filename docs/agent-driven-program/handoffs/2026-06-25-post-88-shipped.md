# Session Handoff — #88 SHIPPED · 5 issues left

**Date:** 2026-06-25 · **Author:** prior session (shipped #88 → PR #90) · **For:** next session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (§1 North Star + §6 ledger), this handoff, and `[[feedback_orientation_preamble_dialogue_skills]]`. **Delta vs last handoff: #88 shipped; backlog 6 → 5.**

---

## 0. ⚠️ FIRST ACTION — push the pending bookkeeping commit

`main` will be **1 commit ahead of origin** after this session: the bookkeeping commit (this handoff + the SPEC §6 ledger row for #88) is committed locally but **unpushed** — the auto-mode classifier blocks direct-to-main pushes. The PR merge (`6391ff7`) and all three tags ARE already on origin; only this docs commit is local.

**Run before starting new work:**
```
! git push origin main
```
Then `git rev-list --left-right --count origin/main...main` should read `0 0`. (Or add a Bash permission rule to let the agent push ledger/docs commits directly.)

---

## 1. What this session did

**Shipped #88** → PR **#90** squash-merged (`6391ff7`), tags `ai-mentor-v2.1.0` + `architect-critic-v0.4.0` + `scaffold-onboard-v0.11.0`. The agent-driven "📍 You are here" orientation preamble for dialogue/cognitive skills.

- **ai-mentor v2.1.0** (owns the convention): `grill-me` + `council` open with the block before the first question / before convening the personas.
- **architect-critic v0.4.0** (adopts): `critiquing-spec` emits it at **Step 4** — after the artifact resolves (Step 1), before the host self-audit (Step 5). **One insertion covers both the synchronous and `--async` close-depth paths** (they share Steps 1–5).
- **scaffold-onboard v0.11.0** (axis-B): the memory-bank `WORKFLOW.md` template documents the convention so projects *built with* the scaffold inherit oriented dialogue/cognitive work.
- New manual behavior-fixture checklist `ai-mentor/tests/test-orientation-preamble.md` (registered in `ai-mentor/tests/README.md`).

**The block:** Topic / Where-it-sits + strategic-weight / Why. Triggers = **open-of-session + on-demand re-surface** ("where am I?"). Derived from a referenced issue/PR + memory-bank (`00-project-brief`, MASTER-SPEC §, SPEC ledger) + recent handoffs; **asks the user when context is thin — never fabricates**. Pure-prose, fully agent-driven — **no deterministic helper, no templating, no hook** (binding #88 constraint).

---

## 2. Two decisions worth remembering

1. **Axis-B was taken IN scope** (user-chosen via AskUserQuestion) and implemented as the **lightweight WORKFLOW.md convention note**, NOT a Karpathy-style Phase-10 opt-in gate. Rationale: the orientation is documentation of a convention (it only has effect if the project runs a cognitive skill), not an imposed behavioral discipline — a new Phase-10 question + state + conditional render + tests would have been over-engineering. The Karpathy opt-in precedent is for *opinionated discipline*; this isn't that. [[feedback_skill_first_avoid_overengineering]]

2. **The dual-publish parity guard is the real version gate.** `tests/test-codex-dual-publish.sh` enforces `.claude-plugin/plugin.json` ↔ **`.codex-plugin/plugin.json`** version parity — marketplace.json carries **no** version field. Every release bumps **both** manifests per plugin (+ README table/tree). A bump touching only `.claude-plugin` silently drifts Codex installs.

**Bot review was clean in 2 light rounds** (batch-fix-in-one-pass): both findings were docs-nits, no product bug — CodeRabbit caught a CHANGELOG line starting with `#88` that markdownlint parsed as a heading (fixed by re-tagging `SS-6 — #88 …` to match the file's own convention); Devin caught the new fixture missing from the `tests/README.md` inventory (registered it), then a follow-on stale "three checklists" → "four" count. Merged on CLEAN + CodeRabbit/Devin SUCCESS + 0 unresolved. [[feedback_bot_review_batch_fix_one_pass]]

---

## 3. Program state snapshot

**Plugin versions (current `main`):** workspace-init **0.4.0** · scaffold-onboard **0.11.0** · scaffold-dev **0.13.0** · architect-critic **0.4.0** · claude-security-audit **0.1.3** · ai-mentor **2.1.0**.

**Tags this session:** `ai-mentor-v2.1.0` + `architect-critic-v0.4.0` + `scaffold-onboard-v0.11.0` (on merge `6391ff7`).

**Open backlog (5):** **#86** (strategic — `/amend-spec`; brainstorm-first; likely a new sub-spec — arguably the highest-value open item) · #85 (small chore — `--separate-git-dir` canonical hook-path) · #38, #37, #10 (reconsider-first). All enhancement/chore — **zero correctness bugs.**

**Repo state:** `main` is **1 ahead of origin** — bookkeeping commit unpushed (see §0). PR merge `6391ff7` + all three tags ARE on origin. Otherwise clean tree (only `.claude/` + `docs/superpowers/` untracked). 0 open PRs. CI green. #88 CLOSED.

---

## 4. ⚠️ The orientation working convention is now plugin-native

#88 baked the "📍 You are here" convention into ai-mentor (`grill-me`/`council`) and architect-critic (`critiquing-spec`). When you run any of those, the orientation now fires from the skill itself — you no longer hand-roll it. For `superpowers:brainstorming` (community-owned, not editable) and any project-authored cognitive flow, **still open with the block by hand** per [[feedback_orientation_preamble_dialogue_skills]]; derived projects get it via the seeded `WORKFLOW.md`.

---

## 5. Recommended next-session entry points

1. **#86** — `/amend-spec` (the strategic greenfield→full-lifecycle gap; **brainstorm-first**; likely a new sub-spec). Highest-value open item, demand-validated by PulseDB v0.5.x→vNext.
2. **Decision session (#38/#37/#10)** — value-reconsideration before any build ([[feedback_reconsider_deferred_before_building]]).
3. **#85** — fold the `--separate-git-dir`-canonical hook-path fix into a future workspace-init touch (low priority).

**Above all: keep opening PRs with batch-fix-in-one-pass, and keep cognitive skills agent-driven (no determinism).**
