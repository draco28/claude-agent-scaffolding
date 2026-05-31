# SPEC — Lean-index memory bank + /defer + blocker-recall (scaffold-dev #33, A+B)

**Date:** 2026-05-31 · **Plugins:** `scaffold-dev` + `scaffold-onboard` · **Ships in:** the combined v0.2 PR on `feat/pr-hierarchical-merge-mode`
**Issue:** [#33](https://github.com/draco28/claude-agent-scaffolding/issues/33) — *lean-index memory bank + deep-reference channels*
**Status:** Design approved (brainstorm 2026-05-31). Scope = **Parts A + B only** (the issue's flagged primary ask). Next: `writing-plans` → implement on branch.

> **Decision lens (binding):** [[feedback_agent_review_over_deterministic_gates]]. The *decisions* in this feature are the orchestrator agent's, made with judgment; only mechanical I/O (`gh` calls, file appends, remote checks) is deterministic. **There is explicitly NO deterministic parser** that extracts a `deferred:` grammar from `report.md` — that brittle pattern is what produced #36/#44. The agent reads the full report and reasons.

---

## 1. Problem

The memory bank accumulates full prose: it overloads, duplicates content already in MASTER-SPEC/SRS/ADRs, and goes stale. Deferred work (tech debt, non-blocking gaps) surfaced mid-slice has no clean "defer → remember leanly → recall when blocked" loop, so the same gap gets re-derived or mistaken for a defect in a later session.

## 2. Goal (Parts A + B)

- **A — Tech-debt → GitHub issue, lean index.** A non-blocking gap becomes (i) a **GitHub issue in the project (canonical) repo** and (ii) a **single `[TD] <desc> → #N` line** in a dedicated memory-bank index — no full-prose duplication. Two filing paths, **both orchestrator-side and agent-driven**: an interactive `/defer`, and an automatic round-close sweep of implementation reports.
- **B — Blocker-recall.** Before a work item halts on "X is missing / why wasn't this done?", the local tech-debt index (implementer-side) and open issues (orchestrator-side) are consulted **first**; a match surfaces "known — see #N" instead of re-deriving or assuming a defect.

### Non-goals (this cycle)
- **Parts C, D, E, F are out of scope** (doc-anchor refs + validator; ADR pointers; claude-mem pointers; lean-index linter). Deferred to a later cycle.
- **No marketplace-repo routing.** A+B file to the **project (canonical) repo** only. The issue's "scaffold-tooling debt → marketplace repo" split is deferred.
- **No deterministic `report.md` deferral parser / grammar.** The orchestrator reads and judges.
- **The implementer-agent gains no `gh` access** — the §6.1 tool-restriction boundary is preserved; issue filing is orchestrator-only.

---

## 3. The deterministic / agent split (the spine)

**Agent-driven (orchestrator session, judgment):**
- Reading each `report.md` in full at round-close and **deciding** which deferrals warrant an issue.
- **Composing** issue title / body / unblock-condition / trace-ids (FR/NFR/Backlog) — with judgment, not a rigid form.
- **Deciding** whether a newly-surfaced gap duplicates an already-open issue (de-dup) before filing.
- **Composing** the `[TD] <desc> → #N` index line.
- Blocker-recall: **judging** whether a local `[TD]` entry or an open issue matches the current gap.

**Deterministic (mechanical facts only — `lib/pr.sh`):**
- `sd_issue_create <title> <body-file> [--label <l>...]` → `gh issue create` from `cd "$canonical"`; echoes the new issue number/URL. rc≠0 + actionable message on failure.
- `sd_issue_list [<gh-args>...]` → `gh issue list --state open --json number,title,body,labels` from `cd "$canonical"`; emits raw JSON for the agent to reason over. **No interpretation.**
- `sd_remote_check` (reuse from #40) → guards both, refusing fast if `origin`/`gh`/auth missing.

No bash parses `report.md`; no bash string-matches issues against gaps.

---

## 4. Component A1 — `/defer` (interactive path)

- **Command:** `scaffold-dev/commands/defer.md` — follows the established `$ARGUMENTS` env-var bridge (`SCAFFOLD_DEV_ARGS`), then invokes `Skill(scaffold-dev:deferring-work-item)`. (Pattern per [[feedback_slash_command_dollar_n_bug]].)
- **Skill:** `scaffold-dev/skills/deferring-work-item/SKILL.md`. Orchestrator-side. Steps:
  1. `sd_remote_check` — refuse fast (mirror the manifest-absent refusal style) if `gh`/auth/remote absent.
  2. Gather/elaborate the deferral with the user as needed (what · why-deferred · unblock-condition · any FR/NFR/Backlog trace-ids). The skill **composes** the issue body with judgment from whatever the user provides — it does not demand a rigid template.
  3. Optional **de-dup**: `sd_issue_list` → judge whether an open issue already covers this; if so, surface it and offer to reuse rather than file a duplicate.
  4. `sd_issue_create` → capture `#N`.
  5. Append `[TD] <desc> → #N` to the memory-bank `tech-debt.md` (append-or-create; §6).
  6. Confirm to the user: filed `#N`, indexed.
- **Forbidden from the implementer-agent** (no `gh`); the §6.1 restriction stands. `/defer` is an orchestrator/user surface.

## 5. Component A2 — round-close auto-file (mechanical capture, agent decisions)

- **Where:** `planning-vertical-slice` §8.7 (round-complete), after the round's items have verified + merged (the orchestrator already holds each `report.md` in context from §8.4–8.5).
- **`report.md` "Deferrals" section** (already exists, `executing-work-item` §6): the implementer writes deferrals **in prose** — a human-readable note per deferral (what didn't get done + why it's non-blocking). No machine grammar. The `executing-work-item` SKILL.md §6 + `templates/implementation-report.md.tmpl` get a one-line clarification that this section is the input the orchestrator reads at round-close to consider issue-filing.
- **Flow (agent-driven):** at §8.7 the orchestrator reads the round's reports, **judges** which Deferrals merit a GitHub issue (skipping trivia / already-tracked items — using `sd_issue_list` judgment for de-dup), surfaces the proposed issues to the user for a **single quick batch confirm**, then for each confirmed item files via `sd_issue_create` and appends the `[TD] → #N` line — i.e. it reuses the §4 `deferring-work-item` filing logic. Never files silently (light human checkpoint); never blocks on it.

## 6. Component A3 — `tech-debt.md` lean index

- **A dedicated memory-bank file** holding only `[TD] <desc> → #N` pointer lines (+ a short header explaining the format). No prose duplication of the issue body — the depth lives in the GitHub issue.
- **scaffold-dev:** append-or-create — if the file is absent (existing projects), create it with the header on first write; otherwise append. (A tiny mechanical append; the line content is agent-composed.)
- **scaffold-onboard:** seed an empty `tech-debt.md` as a **first-class memory-bank template** so new projects are pre-wired. New entry in `scaffolding-memory-bank`'s file set + its index. (File name avoids colliding with the numbered 00–08 set and the harvest's referenced `09-known-issues.md`/`10-decisions-log.md`; use the unprefixed `tech-debt.md`.)
- **Implementer-readable** (plain file, no `gh`) — this is what blocker-recall layer 1 consults.

## 7. Component B — blocker-recall (two layers, both agent-judged)

- **Layer 1 — implementer-side** (`executing-work-item` §3.4, the spec-ambiguity pre-flight scan): before returning a `gaps-surfaced` blocker, the implementer **reads `tech-debt.md`** and judges whether the gap is already a known/tracked item. If so, it surfaces "known — see #N" in its return rather than presenting it as a fresh unresolved gap. Reads the local file only (no `gh`).
- **Layer 2 — orchestrator-side** (`planning-vertical-slice` §8.4, on a `gaps-surfaced` return): before re-dispatching or escalating to the §12.2 menu, the orchestrator runs `sd_issue_list` and **judges** whether an open issue already covers the surfaced gap; if so it surfaces "known — see #N" and folds that into the clarification instead of treating it as novel.
- Both are advisory recall, not gates — they inform the human/agent, never auto-suppress a genuine blocker.

## 8. Manifest routing & degradation

- Project debt → **canonical (project) repo**, inferred from canonical's `origin` remote (no new manifest field — same as #40's `gh` primitives). `cd "$canonical" && gh issue …`.
- `pr_hierarchical`-independent: `/defer` and round-close auto-file work in any merge mode.
- **Degradation:** missing `gh` / not authenticated / no `origin` → `sd_remote_check` refuses with an actionable message. `/defer` surfaces it and stops; round-close auto-file surfaces it and skips filing (the implementer's prose Deferrals remain in `report.md` for later), without blocking round-close.

## 9. Testing

- **Mechanical primitives** — extend `tests/test-pr.sh` (gh PATH-shim): `sd_issue_create` arg-correctness + echoed number; `sd_issue_list` JSON passthrough; degradation when `gh`/remote absent. New fixtures: `tests/fixtures/issue-create-output.txt`-style canned output + `issue-list.json`. Extend the shim to handle `issue create` / `issue list`.
- **Agent decisions** — validated by **eval scenarios (LLM-judge)**, not bash asserts:
  - `evals/` for `deferring-work-item` (new): `/defer` composes a sensible issue + de-dups against an existing open issue + writes the `[TD]` line.
  - `evals/planning-vertical-slice.md`: round-close reads reports, judges which Deferrals merit issues, surfaces for confirm, files + indexes.
  - `evals/executing-work-item.md`: blocker-recall layer 1 — a gap already in `tech-debt.md` is surfaced as "known — see #N" rather than a fresh blocking gap.
- **Full suites stay green** for both plugins (run the whole suite each).

## 10. Rollout

- scaffold-dev already at **v0.2.0** on the branch (no further bump for #33).
- **scaffold-onboard:** patch bump (0.3.7 → 0.3.8 — after #44's 0.3.7) in **both** `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` (dual-publish parity) + README row, for the `tech-debt.md` template addition.
- Ships in the single combined v0.2 PR with #40 + #44.

## 11. Open items carried into planning
- Exact `tech-debt.md` header text + `[TD]` line format (kept lean — desc + `→ #N`, optional one-word area tag).
- Exact wording of the §8.7 round-close orchestrator instructions (judge-then-confirm-then-file; never silent, never blocking).
- The `deferring-work-item` skill body's elaboration prompts (what/why/unblock/trace-ids) — guidance, not a rigid form.
- Whether `sd_issue_create` should accept a default label (e.g. `tech-debt`) — lean yes; confirm at implementation.
