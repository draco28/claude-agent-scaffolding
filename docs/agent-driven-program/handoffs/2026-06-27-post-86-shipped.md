# Session Handoff — #86 SHIPPED (SS-8 `/amend-spec`) · 5 issues left

**Date:** 2026-06-27 · **Author:** prior session (shipped #86 → PR #91) · **For:** next session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (§1 North Star + §5 SS-8 + §6 ledger), this handoff, `specs/SS-8-amend-spec.md`. **Delta vs last handoff: #86 shipped; #92 filed; backlog stays 5.**

---

## 0. ✅ Repo fully synced — no pending push

`main` is **fully synced with origin** (`git rev-list --left-right --count origin/main...main` → `0 0`). The PR merge (`a3c8b9c`), tag `scaffold-onboard-v0.12.0`, and the bookkeeping commit (`61ab9a1`: SPEC §5/§6 SHIPPED flip + this handoff) are all on origin. **#86 CLOSED. 0 open PRs.** Start the next task clean.

> Note for next session: this session's direct-to-main bookkeeping push went through on explicit user authorization. Expect the auto-mode classifier to require an explicit `! git push origin main` (or a scoped permission rule) again at the next closeout.

---

## 1. What this session did

**Shipped #86** → PR **#91** squash-merged (`a3c8b9c`), tag `scaffold-onboard-v0.12.0`. The **`/amend-spec`** skill (`amending-spec`) — a **fully agent-driven front-door MVP** for incremental, change-driven MASTER-SPEC amendment at the post-MVP / vNext lifecycle boundary (SS-8).

- **scaffold-onboard v0.12.0**: new `skills/amending-spec/SKILL.md`, `commands/amend-spec.md`, `tests/test-amend-spec.md` (12 manual fixtures), `specs/SS-8-amend-spec.md` design-of-record. **Zero new `lib/*.sh`.**
- **The flow:** 📍 orient → preflight → classify (pure-maintenance → `/defer`) → impact analysis (confirmation gate) → targeted phase-section edit + `## Revision History` + bumped `**Spec revision:**` (schema `**Spec version:**` pinned) → SSoT `phase_record` fold-forward → EXEC-SUMMARY judgment → propagation handoff.
- **Brainstorm-first**, settled **four forks** with the user (AskUserQuestion): (1) front-door MVP, **defer the doc-merge**; (2) SSoT consistency = edit spec **+** fold a note into `phase_record`; (3) amendment trail = `## Revision History` + new `**Spec revision:**` field (NOT bumping the schema `Spec version`); (4) **ID minting deferred with the doc-merge** (MASTER-SPEC is ID-free; `/scaffold-docs` re-mints wholesale, so `/amend-spec` surfaces the prospective requirement but writes no ID).

---

## 2. Two things worth remembering

1. **New PR division of labor (now a saved preference — [[feedback_codex_runs_pr_fix_cycle]]).** The user's **Codex companion runs the review-fix cycle** (addresses all Codex/CodeRabbit/Devin findings, batch-fix-in-one-pass, verifies, pushes, resolves threads, stops at "mergeable"); **Claude reviews Codex's actual commits + does the final merge + closeout.** On #91, Codex's one commit (`fe4200e`) fixed **3 real draft bugs** I'd missed — invalid `roadmap_append_mutation` mode (`amend-spec` isn't a mode → use `add-slice`), lock-release-on-failed-acquire, and the EXEC-SUMMARY H1/H2 shape (the producer rejects an already-rendered file) — plus a `project_mismatch` safety stop. I verified on the real HEAD (all 14 cited `sf` helpers resolve; suite 21/0; dual-publish 154/0) before merging — not on the summary alone. A **reusable Codex prompt** for this loop now lives with the user.

2. **Deferred-by-design honesty.** `/amend-spec` edits only MASTER-SPEC + handoff; it does **not** touch SRS/BACKLOG/PRD and writes **no ID**. The honest MVP limitation: doc propagation is whole-bundle `/scaffold-docs` re-derive (curated doc edits get re-authored). The diff-aware doc-merge + stable ID minting are future enhancements (the #58-class complexity, one layer down).

---

## 3. Program state snapshot

**Plugin versions (current `main`):** workspace-init **0.4.0** · scaffold-onboard **0.12.0** · scaffold-dev **0.13.0** · architect-critic **0.4.0** · claude-security-audit **0.1.3** · ai-mentor **2.1.0**.

**Open backlog (5):** **#92** (NEW — scaffold-dev: expose the #82 pre-merge gate / finding-disposition loop as a standalone slice-decoupled `/work-pr` command; **brainstorm-first**; the manual Codex prompt is re-deriving a contract scaffold-dev already owns) · #85 (small chore — `--separate-git-dir` canonical hook-path) · #38, #37, #10 (reconsider-first). All enhancement/chore — **zero correctness bugs.**

**Repo state:** `main` **fully synced with origin** at `0 0` (PR merge `a3c8b9c` + tag `scaffold-onboard-v0.12.0` + bookkeeping `61ab9a1` all on origin); #86 CLOSED; 0 open PRs. Clean tree (only `.claude/` + `docs/superpowers/` untracked).

---

## 4. Recommended next-session entry points

1. **#92** — the `/work-pr` extraction (scaffold-dev). Highest-leverage: turns the manual Codex PR-fix prompt into a first-class command, reusing the #82 `git-workflow.md` disposition contract + `sd` primitives + `/defer`. **Brainstorm-first** (the real design question is the slice-coupling vs PR-generic boundary).
2. **Decision session (#38/#37/#10)** — value-reconsideration before any build ([[feedback_reconsider_deferred_before_building]]).
3. **#85** — fold the `--separate-git-dir`-canonical hook-path fix into a future workspace-init touch (low priority).

**Above all: keep the Codex-runs-fix-cycle / Claude-reviews-and-merges split, verify on the real HEAD (not the summary), and keep cognitive/agent-driven skills free of unnecessary determinism.**
