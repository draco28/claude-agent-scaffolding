# Program Spec — Agent-Driven Scaffold Ecosystem (zero-backlog roadmap)

**Status:** Draft (program-level) · **Date:** 2026-06-01 · **Supersedes the planning role of:** `docs/SPEC-issue-backlog-triage.md` (tiers folded in below)
**Scope:** `workspace-init` + `scaffold-onboard` + `scaffold-dev` (three-plugin refactor)
**Why this doc exists:** A durable, cross-session plan. Any new orchestration session resumes from here: the north-star model, the three root anti-patterns, the phased sub-specs, and a per-issue ledger that drives the GitHub backlog to **zero**.

> **Decision provenance:** Settled with the user 2026-06-01 (Option C — full mechanical→agent-driven refactor; `#45` is the *wedge*, not the job). Memory: `project_agent_driven_first_class_pivot`. Builds on the promoted principle `feedback_agent_review_over_deterministic_gates` (architect-critic `pp-e72993dfb626c518`).

---

## 1. North Star

**Agent-driven is the first-class workflow. Bash/deterministic code is reserved exclusively for non-reasoning facts.**

- **Reason / judge / author content → dispatch a sub-agent (or reason in-conversation).** Deriving a spec, a doc, a memory-bank file, a slice decomposition, a review verdict — all reasoning.
- **Mechanical-only (KEEP) → bash.** File I/O, path resolution, `git`/`gh` invocation, exit-code checks, JSON state read/write, parse-validity, idempotent fixed-format appends, atomic writes, locking. No judgment.
- **Derivation is reconciliation, not regeneration.** Re-deriving any artifact **merges** new source-of-truth with the existing file — refresh spec-derived prose, **preserve** accumulated learnings (harvest entries, machine-checkable rules, user edits). An agent can do this 3-way merge; a template `>` redirect cannot. This is the single idea that dissolves `#45` and its whole blast radius.
- **One source of truth per job.** Never a mechanical parser *and* an agent path both claiming the same extraction with no authority. Pick one (prefer the agent per the agent-review principle); the other becomes an explicit, labeled fallback.
- **SSoT = `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md`, themselves agent-synthesized and reconcilable.** Not template fill-in.

**Non-goal:** ripping out bash wholesale. Most of `workspace-init` and all the git/state plumbing is *correctly* mechanical and stays. The refactor targets reasoning-forced-into-mechanism, not mechanism itself.

---

## 2. The three root anti-patterns (audit, 2026-06-01)

A six-stream audit of the full flow (`workspace-init → /onboard → /scaffold-docs → /plan-roadmap → /scaffold-project → scaffold-dev`) collapsed every flagged site into three classes. **This is the spec's backbone — each sub-spec kills one or more.**

### A · Regeneration, not reconciliation
Re-derive overwrites wholesale instead of merging accumulated knowledge.
- `scaffold-onboard/lib/memory-bank.sh:84-88` — the 8 derived files render unconditionally (no skip-check even without `--regenerate`). Only `AGENTS.md` gets a managed-section merge (`sf_agents_merge_managed_section`).
- Harvest (`closing-vertical-slice`) + machine-checkable rules (`authoring-machine-checkable-rules`) write into derived `03`/`04` → **clobbered** on next `/scaffold-project`.
- `/scaffold-docs` re-derive is skip-if-exists or `--regenerate` wholesale clobber; merge is a documented non-goal.
- **This is `#45`'s root**, and the same defect at the docs layer.

### B · Mechanical transcription where synthesis belongs
Raw answers slotted into `{{placeholders}}`; reasoning assumed to have happened "in the conversation" and stored as flat strings.
- `MASTER-SPEC.md` is built by `sf_master_spec_update_phase` substituting raw phase answers into `{{phase_1.1.1}}` slots — **transcription, not synthesis.**
- `EXECUTIVE-SUMMARY.md` has a `{{executive_summary}}` placeholder with **no source question and no implemented render function** — a hole (`sf_render_executive_summary` is referenced in SKILL.md but does not exist).
- `/scaffold-docs` default run appears to emit template stubs carrying literal `TODO:` / `*(populate after planning)*` markers.

### C · Dual-path / grammar-collision
A mechanical parser *and* an agent path both claim one job; prose that doesn't match the assumed grammar is silently dropped, or the two paths simply disagree.
- `scaffold-dev/lib/harvest.sh` AWK parser assumes `- target_file: X / suggestion: Y` bullets, but `executing-work-item`'s report template lets implementers write free-form prose → real suggestions silently lost. Meanwhile `closing-vertical-slice` SKILL.md describes harvest as *agent-judged*. Two harvests, no authority.
- Bash `sf_memory_bank_derive` (always overwrite) vs SKILL.md §13 synthesis prose (skip-if-exists) **disagree** on re-derive semantics.
- Work-item AC grammar is author-validated only; malformed `auto:` lines pass authoring and misfire at the verification gate.

---

## 3. Per-flow audit verdict (durable record)

| Flow | Verdict | Anti-patterns present |
|---|---|---|
| **workspace-init** (init/pair) | **Legitimately mechanical — leave it.** Git/repo plumbing, `jq` manifest, rollback. Only soft flag: 3 static stub templates (boilerplate, low stakes). | — (B-lite, deferred) |
| **/onboard → MASTER-SPEC** | Q&A + critic moments are agent; **MASTER-SPEC is mechanical transcription**; EXEC-SUMMARY is an unimplemented hole. | **B** |
| **/scaffold-docs** | Synthesis briefs + `synthesis-agent` exist & are tested, but the default likely **falls through to template stubs** (synthesis "shipped but not exercised end-to-end" — corroborated by memory `project_scaffold_onboard_v03_synthesis_design`). No merge on re-derive. | **A, B** |
| **/plan-roadmap** | **~95% agent-driven and correct.** User dictates, Claude judges; only state-I/O + ROADMAP render are mechanical (legit). Slice content interactive-not-synthesized *by design*. | — (minor; v0.3 synthesis hook optional) |
| **/scaffold-project** (memory bank) | **The epicenter.** Bash path overwrites 8 derived files + CLAUDE.md unconditionally; harvest + mcrules clobbered; phantom target files. | **A, C** |
| **scaffold-dev** (slices/work-items/close) | Substantially **agent-driven** (decomposition, dispatch, demo-judging, critic). Plumbing legit-mechanical. Flags are grammar-collision seams. | **C** |

---

## 4. Target model (what "fixed" looks like)

1. **Reconciliation primitive.** A reusable mechanism: given `(source-of-truth, existing-artifact)`, an agent produces a merged artifact that refreshes SoT-derived prose and preserves accumulated/append zones. Used by memory-bank derive, governance derive, and MASTER-SPEC enhancement re-runs. The deterministic template render becomes the explicit `--fast` fallback, never the silent default.
2. **Agent-first derivation, on by default.** `/scaffold-project` and `/scaffold-docs` dispatch synthesis sub-agents by default; bash render is `--fast` opt-in. Verified by an actual invocation trace (see OQ-1).
3. **Synthesized, resumable, reconcilable SSoT.** Onboarding persists a phased-discussion file (resumable across sessions); at completion an agent synthesizes MASTER-SPEC + EXEC-SUMMARY via a **tool-agnostic plugin prompt** (Claude *or* Codex); scratch file deleted; enhancement re-runs reconcile a new phased-answer file into the existing SSoT.
4. **Single authority per extraction.** Harvest, deferrals, suggestions, spec-citations: the agent reads and judges; any bash helper is a labeled fallback, not a competing parser.
5. **Mechanical boundary, explicit.** A short "what stays bash" list lives in the memory bank / governance so future work doesn't re-litigate it (exit codes, `gh`/git rc, path resolution, parse-validity, atomic writes, locking, fixed-format appends).

---

## 5. Phased sub-specs

Each sub-spec gets its own `brainstorm → writing-plans → build → bot-review → release` cycle later. Sequencing respects dependencies; cleanup interleaves.

### SS-1 — Reconciliation engine + `#45` (anti-pattern A core) · **FOUNDATIONAL, FIRST**
Build the managed-merge primitive for derived memory-bank + governance files (generalize the `AGENTS.md` managed-section merge). Fix harvest's target-set (kill phantom `09`/`10`/`06-product-context`; correct "11-file"→"12-file"), make the harvest/mcrules append zone survive re-derive, and rewrite the CLAUDE.md SSoT note to distinguish spec-derived prose from accumulated learnings.
**Closes:** `#45`. **Partially:** `#48` C/D/E (reconciliation helpers).

### SS-2 — Turn synthesis ON + verify + post-derivation review (anti-pattern A/B) · depends on SS-1
Verify whether synthesis actually dispatches by default (OQ-1); repair if dark. Wire the SS-1 reconciliation primitive into the re-derive path of **both** `/scaffold-project` and `/scaffold-docs`. Make `--fast` the explicit fallback. Add `#42`'s agent-driven post-derivation review as the QA gate over synthesized output.
**Closes:** `#42`, **N2** (dark-synthesis), **N1** (EXEC-SUMMARY hole if not taken by SS-3). Dissolves the `TODO:`-stub problem.

### SS-3 — Agent-synthesized, resumable onboarding (anti-pattern B + resumability) · parallel-eligible after SS-1
Implement the user's onboarding design: **phased-discussion file** (durable, resumable mid-onboarding across sessions) → at phase-completion an agent **synthesizes** MASTER-SPEC + EXEC-SUMMARY from it via a **tool-agnostic plugin prompt** (Claude or Codex) → **delete** the scratch file → enhancement re-run produces a new phased-answer file that **reconciles** into the existing SSoT.
**Closes:** **N3** (MASTER-SPEC transcription→synthesis), **N1** (EXEC-SUMMARY hole). **Enables:** Codex-run synthesis (ties to SS-5).

### SS-4 — Agent-review of the verification seams (anti-pattern C) · independent
Resolve dual-path/grammar-collisions by making the **agent the single authority** (per the promoted principle); bash becomes labeled fallback. Covers harvest suggestions/deferrals extraction, spec-citations (`#7`), RED-tests-gate framing (`#5`), lean-index linter (`#48` Part F).
**Closes / dissolves:** `#7`, `#5` (reframed agent-driven), `#48` Part F, **N4** (harvest grammar-collision).

### SS-5 — Codex implementer/synthesizer backend (`#47`) · independent
Manifest-configurable `implementer_backend ∈ {claude_subagent, codex}` via `codex-companion.mjs task`; the no-commit/stage-only contract is prompt-carried + orchestrator-verified (no hard block under `workspace-write`). SS-3's tool-agnostic synthesis prompts mean Codex can also run derivation.
**Closes:** `#47`.

### SS-6 — Standalone cleanup to zero (independent items) · interleave
Items unrelated to the derivation pivot — clear them to reach zero backlog:
`#8` (ban `git stash`; stays deterministic — legit), `#9` (Scenario C pairing), `#6` (ADR Proposed→Accepted flip), `#10` (coordinating-parallel-slices, demand-gated), `#37`/`#38`/`#39` (external-benchmark trio; `#38` redaction has standalone safety value), `#48` remainder (`/defer` marketplace routing, label auto-create), **N5** (repo CI for shell suites).
**Closes:** the 9 independent issues + N5.

---

## 6. Issue ledger → zero backlog

Every open issue + every new audit finding, mapped to a sub-spec. **Target: 0 open issues.**

| # | Title (short) | Pivot relation | Sub-spec | Target |
|---|---|---|---|---|
| **#45** | harvest ↔ derived-file SSoT contradiction | wedge / partial | **SS-1** | v0.2 |
| **#42** | agent-driven post-derivation doc review | **dissolved** (is the refactor) | **SS-2** | v0.2 |
| **#7** | verifying-spec-citations (agent-assisted) | **dissolved** | **SS-4** | v0.2 |
| **#5** | pre-flight RED-tests gate | partial (reframe) | **SS-4** | v0.2 |
| **#48** | #33 C–F + /defer routing + label auto-create | partial | **SS-1** (C/D/E) + **SS-4** (F) + **SS-6** (routing/label) | v0.3 |
| **#47** | Codex implementer backend | independent | **SS-5** | v0.3 |
| **#8** | ban `git stash` in templates | independent (keep-mech) | **SS-6** | v0.2 |
| **#9** | pairing-existing-dual (Scenario C) | independent | **SS-6** | v0.2 |
| **#6** | ADR Proposed→Accepted flip | independent | **SS-6** | v0.3 |
| **#10** | coordinating-parallel-slices | independent (demand-gated) | **SS-6** | v0.3 |
| **#37** | grilling domain-language + ADR thresholds | partial (principle) | **SS-6** | v0.3 |
| **#38** | handoff suggested-skills + redaction | partial | **SS-6** | v0.3 |
| **#39** | architect-critic async adversary | independent | **SS-6** | v0.3 |

**New issues filed from this audit** (2026-06-01, so the backlog reflects reality):

| ID | Issue | Title | Type | Sub-spec |
|---|---|---|---|---|
| **N1** | **#49** | scaffold-onboard: EXECUTIVE-SUMMARY placeholder has no source question / render fn (hole) | bug | SS-3 (or SS-2) |
| **N2** | **#50** | scaffold-onboard: verify synthesis path actually dispatches by default (possibly "dark" / never exercised end-to-end) | bug · critical | SS-2 |
| **N3** | **#51** | scaffold-onboard: MASTER-SPEC is mechanical transcription — move to agent synthesis from phased-discussion | enhancement | SS-3 |
| **N4** | **#52** | scaffold-dev: harvest grammar-collision — AWK parser silently drops free-form Suggestions prose; single-authority agent read | bug | SS-4 |
| **N5** | **#53** | repo: no `.github/workflows` CI for shell test suites | ops | SS-6 |

---

## 7. Codex daily-run findings disposition (2026-06-01)

Codex ran against the **stale pre-merge branch** (reported "44 commits ahead of origin/main"; `gh` API unreachable). Verdicts:

| Finding | Disposition |
|---|---|
| `#44` slice-demo grammar "still open" | **STALE** — shipped & closed in PR #46. The "output contains / count > 0 vs hardened AC grammar" mismatch is now **intentional by design** (#44's resolution). One-line doc check that `SPEC-scaffold-dev.md` reflects the resolution. |
| README/manifests still v0.3.8 / v0.2.0 | **STALE** — those ARE the shipped, tagged versions (bumped during the merge). |
| Untracked `.claude/` | **Genuine but known hygiene** (standing don't-commit gotcha). Not a product bug. |
| No `.github/workflows` CI | **GENUINE** → **N5** (SS-6). |
| `gh` API unreachable | Environmental; resolved (we list issues fine now). |

---

## 8. Open questions (settle before/within the relevant sub-spec)

- **OQ-1 (gates SS-2):** Does `/scaffold-project` + `/scaffold-docs` *actually* dispatch synthesis on a default run, or fall through to deterministic stubs? Verify by tracing one real invocation. Memory + three audit streams suggest "dark," but this must be confirmed before SS-2 framing. **If dark → SS-2 is "turn it on"; if live → SS-2 is "fix the model."**
- **OQ-2 (SS-1):** Reconciliation merge unit — managed-section markers (like `AGENTS.md`) vs. whole-file agent merge? Markers are cheaper/deterministic to preserve; whole-file agent merge is more flexible but costs a sub-agent per re-derive. Likely: markers for the append zones (harvest/mcrules), agent merge only when SoT prose changed.
- **OQ-3 (SS-3):** Phased-discussion file format + location + lifecycle (resumable schema; where it lives; deletion timing; whether to keep an archived copy for audit vs. hard-delete).
- **OQ-4 (cross-cutting):** Codify the "what stays bash" boundary as a memory-bank/governance artifact so future sessions don't re-litigate.

---

## 9. Cross-session usage

A new orchestration session resumes the program by:
1. Reading this spec (north star + ledger + sub-spec sequence).
2. Picking the next un-started sub-spec per §5 sequencing (SS-1 first).
3. Running its own `brainstorm → writing-plans → build → bot-review → release` cycle (plain superpowers flow — this is the plugin **source** repo, no `.workspace/pairing.json`, so scaffold-dev's slice skills refuse here; handoffs stay manual `docs/HANDOFF-*.md`).
4. Updating the ledger (§6) as issues close. Done when the table is all-closed.

**Release mechanics (per sub-spec):** bump `plugin.json` (Claude **and** Codex — parity enforced by `tests/test-codex-dual-publish.sh`) + README version table → merge → `git tag <plugin>-v<ver>` on the merge commit → push tags.
